import {
  GoogleGenerativeAI,
  SchemaType,
  type ResponseSchema,
} from '@google/generative-ai';

import { resolveAllowedCategory } from './categories';
import {
  CURRENCIES,
  DEFAULT_CURRENCY,
  normalizeCurrency,
} from './currencies';
import {
  DEFAULT_PAYMENT_METHOD,
  normalizePaymentMethod,
  PAYMENT_METHODS,
} from './payment_methods';
import {
  FALLBACK_CATEGORY_NAME,
  resolveMerchant,
  type ParsedTransaction,
} from './schema';

// Prefer lite for SMS→JSON; fall back if unavailable or overloaded.
// 2.5-flash-lite is closed to new API keys; 2.0-flash-lite is retired.
export const GEMINI_MODELS = [
  'gemini-3.1-flash-lite',
  'gemini-2.5-flash',
  'gemini-3.5-flash',
] as const;

export const GEMINI_MODEL = GEMINI_MODELS[0];
export const MIN_PARSE_CONFIDENCE = 0.5;

function buildParsedTransactionSchema(
  allowedCategories: string[],
): ResponseSchema {
  return {
    type: SchemaType.OBJECT,
    properties: {
      amount: {
        type: SchemaType.NUMBER,
        description: 'Transaction amount as a number without commas',
      },
      currency: {
        type: SchemaType.STRING,
        format: 'enum',
        enum: [...CURRENCIES],
        description:
          'ISO currency code — must be exactly one value from the allowed list',
      },
      type: {
        type: SchemaType.STRING,
        description: 'debit or credit',
      },
      merchant: {
        type: SchemaType.STRING,
        description:
          'Primary merchant or payee. Use ATM for cash withdrawals with no named merchant — never Unknown',
      },
      merchantDetails: {
        type: SchemaType.STRING,
        description: 'Secondary merchant location or detail, or Unknown',
        nullable: true,
      },
      category: {
        type: SchemaType.STRING,
        format: 'enum',
        enum: allowedCategories,
        description:
          'Expense category — must be exactly one value from the allowed list',
      },
      paymentMethod: {
        type: SchemaType.STRING,
        format: 'enum',
        enum: [...PAYMENT_METHODS],
        description:
          'Payment rail — must be exactly one value from the allowed list',
      },
      bank: {
        type: SchemaType.STRING,
        description: 'Bank name if known, otherwise Unknown',
      },
      accountId: {
        type: SchemaType.STRING,
        description: 'Masked account or card identifier from the message',
      },
      branch: {
        type: SchemaType.STRING,
        description: 'Branch name if present, otherwise Unknown',
        nullable: true,
      },
      transactionTime: {
        type: SchemaType.STRING,
        description: 'ISO 8601 datetime with timezone offset',
      },
      transactionDate: {
        type: SchemaType.STRING,
        description: 'Date in YYYY-MM-DD format',
      },
      externalId: {
        type: SchemaType.STRING,
        description: 'TID, reference, or STAN if present',
        nullable: true,
      },
      externalIdType: {
        type: SchemaType.STRING,
        description: 'tid, ref, stan, or unknown',
      },
      parseConfidence: {
        type: SchemaType.NUMBER,
        description: 'Confidence from 0 to 1',
      },
    },
    required: [
      'amount',
      'currency',
      'type',
      'merchant',
      'category',
      'paymentMethod',
      'bank',
      'accountId',
      'transactionTime',
      'transactionDate',
      'externalIdType',
      'parseConfidence',
    ],
  };
}

/** Format a Date as Pakistan-local ISO date + datetime for the parse prompt. */
export function formatPakistanNow(now: Date): {
  currentDate: string;
  currentDateTime: string;
} {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Karachi',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);

  const get = (type: Intl.DateTimeFormatPartTypes): string =>
    parts.find((p) => p.type === type)?.value ?? '00';

  const currentDate = `${get('year')}-${get('month')}-${get('day')}`;
  const currentDateTime = `${currentDate}T${get('hour')}:${get('minute')}:${get('second')}+05:00`;
  return { currentDate, currentDateTime };
}

function buildSystemPrompt(
  allowedCategories: string[],
  currentDate: string,
  currentDateTime: string,
): string {
  const categoryList = allowedCategories.join(', ');

  return `You parse transaction text into structured JSON. Inputs may be Pakistani bank SMS/email alerts OR short natural-language descriptions written by users (e.g. "spent 200 at KFC", "salary 150000", "received 500 from Ali").

Rules:
- Amounts must be numbers without commas (e.g. 5990.00 not "5,990.00").
- currency: MUST be exactly one of: [${CURRENCIES.join(', ')}]. Usually ${DEFAULT_CURRENCY} for Pakistani bank SMS; use another code only when clearly stated.
- type must be lowercase "debit" or "credit". Infer from wording when needed (spent/paid/charged → debit; received/salary/credited → credit).
- Dates must use ISO format: transactionDate as YYYY-MM-DD, transactionTime as ISO 8601 with +05:00 for Pakistan.
- If the input is a manual/natural-language entry and does not specify a date or time, use exactly this current date/time supplied by the application: transactionDate=${currentDate}, transactionTime=${currentDateTime}. Never invent another "today" and never use placeholders.
- If a bank message includes a date/time, prefer those values from the message.
- merchant: required. For cash withdrawal / ATM with no named merchant, use "ATM" — never "Unknown". Put ATM location in merchantDetails when present.
- Use "Unknown" for missing merchantDetails, branch, bank, or accountId when not inferable.
- paymentMethod: MUST be exactly one of: [${PAYMENT_METHODS.join(', ')}].
  Map specifics to these generics (e.g. card used → debit_card, credit card → credit_card,
  Raast/IBFT/account transfer → bank_transfer, JazzCash/EasyPaisa → wallet, ATM cash → atm_withdrawal).
  If not inferable, use ${DEFAULT_PAYMENT_METHOD}.
- accountId should preserve masking from bank messages (e.g. xxx1215).
- externalIdType: use tid for TID, ref for reference numbers, stan for STAN, unknown otherwise (typical for manual entries).
- category: MUST be exactly one of these values: [${categoryList}].
  Income: salary, employer/company, investment only. Person-to-person (named individual, P2P, IBFT/Raast) → Transfer, never Income.
  Examples: PSO/Shell/Total → Fuel, McDonald's/KFC → Food & Dining, ATM → Cash Withdrawal, salary → Income, Ali sent 500 → Transfer.
  If none fit, use ${FALLBACK_CATEGORY_NAME}.
- parseConfidence: 0.0-1.0 based on how clearly fields were extracted.

Examples:

Input: PKR 5,990.00 charged at PSO RANGERS>LAH for card used, from A/C xxx1215 (DHA PHASE VIII BR LHR) on 06-Jul-2026 at 11:27 TID:387522
Output: {"amount":5990,"currency":"PKR","type":"debit","merchant":"PSO RANGERS","merchantDetails":"LAH","category":"Fuel","paymentMethod":"debit_card","bank":"Unknown","accountId":"xxx1215","branch":"DHA PHASE VIII BR LHR","transactionTime":"2026-07-06T11:27:00+05:00","transactionDate":"2026-07-06","externalId":"387522","externalIdType":"tid","parseConfidence":0.95}

Input: spent 200 at KFC
Output: {"amount":200,"currency":"PKR","type":"debit","merchant":"KFC","merchantDetails":null,"category":"Food & Dining","paymentMethod":"${DEFAULT_PAYMENT_METHOD}","bank":"Unknown","accountId":"Unknown","branch":null,"transactionTime":"${currentDateTime}","transactionDate":"${currentDate}","externalId":null,"externalIdType":"unknown","parseConfidence":0.9}

Input: PKR 10,000.00 withdrawn from ATM, A/C xxx1234 on 06-Jul-2026 at 11:27
Output: {"amount":10000,"currency":"PKR","type":"debit","merchant":"ATM","merchantDetails":null,"category":"Cash Withdrawal","paymentMethod":"atm_withdrawal","bank":"Unknown","accountId":"xxx1234","branch":null,"transactionTime":"2026-07-06T11:27:00+05:00","transactionDate":"2026-07-06","externalId":null,"externalIdType":"unknown","parseConfidence":0.95}`;
}

export type ParseResult =
  | { ok: true; parsed: ParsedTransaction; model: string }
  | { ok: false; error: string; lowConfidence?: boolean };

function normalizeParsed(
  raw: Record<string, unknown>,
  allowedCategories: string[],
): ParsedTransaction {
  const category = resolveAllowedCategory(
    String(raw.category ?? FALLBACK_CATEGORY_NAME),
    allowedCategories,
  );
  const paymentMethod = normalizePaymentMethod(
    String(raw.paymentMethod ?? DEFAULT_PAYMENT_METHOD),
  );
  return {
    amount: Number(raw.amount),
    currency: normalizeCurrency(String(raw.currency ?? DEFAULT_CURRENCY)),
    type: String(raw.type ?? 'debit').toLowerCase() as ParsedTransaction['type'],
    merchant: resolveMerchant(String(raw.merchant ?? ''), category, paymentMethod),
    merchantDetails:
      raw.merchantDetails == null || raw.merchantDetails === 'Unknown'
        ? null
        : String(raw.merchantDetails),
    category,
    paymentMethod,
    bank: String(raw.bank ?? 'Unknown'),
    accountId: String(raw.accountId ?? 'Unknown'),
    branch:
      raw.branch == null || raw.branch === 'Unknown'
        ? null
        : String(raw.branch),
    transactionTime: String(raw.transactionTime ?? ''),
    transactionDate: String(raw.transactionDate ?? ''),
    externalId:
      raw.externalId == null || raw.externalId === 'Unknown'
        ? null
        : String(raw.externalId),
    externalIdType: String(
      raw.externalIdType ?? 'unknown',
    ).toLowerCase() as ParsedTransaction['externalIdType'],
    parseConfidence: Number(raw.parseConfidence ?? 0),
  };
}

/** Quota, overload, unavailable-model, and capacity errors — try the next model. */
function isRetryableModelError(message: string): boolean {
  const lower = message.toLowerCase();
  return (
    message.includes('429') ||
    message.includes('RESOURCE_EXHAUSTED') ||
    message.includes('503') ||
    message.includes('UNAVAILABLE') ||
    message.includes('404') ||
    lower.includes('high demand') ||
    lower.includes('service unavailable') ||
    lower.includes('no longer available') ||
    lower.includes('not found')
  );
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function generateWithModel(
  apiKey: string,
  modelName: string,
  rawMessage: string,
  allowedCategories: string[],
  currentDate: string,
  currentDateTime: string,
): Promise<string> {
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: modelName,
    systemInstruction: buildSystemPrompt(
      allowedCategories,
      currentDate,
      currentDateTime,
    ),
    generationConfig: {
      responseMimeType: 'application/json',
      responseSchema: buildParsedTransactionSchema(allowedCategories),
      temperature: 0.1,
    },
  });

  const result = await model.generateContent(
    `Current date/time: ${currentDateTime}\n\nParse this transaction message:\n\n${rawMessage}`,
  );
  const text = result.response.text();

  if (!text) {
    throw new Error('Gemini returned an empty response');
  }

  return text;
}

export async function parseTransaction(
  apiKey: string,
  rawMessage: string,
  allowedCategories: string[],
  now: Date = new Date(),
): Promise<ParseResult> {
  if (allowedCategories.length === 0) {
    return { ok: false, error: 'No allowed categories configured' };
  }

  const { currentDate, currentDateTime } = formatPakistanNow(now);
  let lastError = 'Unknown Gemini parse error';
  const attempts: string[] = [];

  for (const [index, modelName] of GEMINI_MODELS.entries()) {
    try {
      const text = await generateWithModel(
        apiKey,
        modelName,
        rawMessage,
        allowedCategories,
        currentDate,
        currentDateTime,
      );
      const json = JSON.parse(text) as Record<string, unknown>;
      const parsed = normalizeParsed(json, allowedCategories);

      if (parsed.parseConfidence < MIN_PARSE_CONFIDENCE) {
        return {
          ok: false,
          error: `Low parse confidence: ${parsed.parseConfidence}`,
          lowConfidence: true,
        };
      }

      if (index > 0) {
        // Surface fallback usage — a 404/"not found" here likely means an
        // earlier model in GEMINI_MODELS is misconfigured or deprecated,
        // not just transiently overloaded, and should be investigated.
        console.warn('Gemini parse succeeded on fallback model', {
          model: modelName,
          skipped: GEMINI_MODELS.slice(0, index),
          attempts,
        });
      }

      return { ok: true, parsed, model: modelName };
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Unknown Gemini parse error';
      lastError = `[${modelName}] ${message}`;
      attempts.push(lastError);

      if (isRetryableModelError(message)) {
        console.warn('Gemini model failed, trying next fallback', {
          model: modelName,
          message,
        });
        await sleep(1500);
        continue;
      }

      console.error('Gemini parse failed with a non-retryable error', {
        model: modelName,
        message,
        attempts,
      });
      return { ok: false, error: lastError };
    }
  }

  console.error('Gemini parse exhausted all fallback models', { attempts });
  return { ok: false, error: lastError };
}
