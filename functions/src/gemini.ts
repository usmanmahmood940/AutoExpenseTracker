import {
  GoogleGenerativeAI,
  SchemaType,
  type ResponseSchema,
} from '@google/generative-ai';

import type { ParsedTransaction } from './schema';

// Prefer lite for SMS→JSON; fall back if unavailable or overloaded.
// 2.5-flash-lite is closed to new API keys; 2.0-flash-lite is retired.
export const GEMINI_MODELS = [
  'gemini-3.1-flash-lite',
  'gemini-2.5-flash',
  'gemini-3.5-flash',
] as const;

export const GEMINI_MODEL = GEMINI_MODELS[0];
export const MIN_PARSE_CONFIDENCE = 0.5;

const PARSED_TRANSACTION_SCHEMA: ResponseSchema = {
  type: SchemaType.OBJECT,
  properties: {
    amount: {
      type: SchemaType.NUMBER,
      description: 'Transaction amount as a number without commas',
    },
    currency: {
      type: SchemaType.STRING,
      description: 'ISO currency code, usually PKR',
    },
    type: {
      type: SchemaType.STRING,
      description: 'debit or credit',
    },
    merchant: {
      type: SchemaType.STRING,
      description: 'Primary merchant or payee name',
    },
    merchantDetails: {
      type: SchemaType.STRING,
      description: 'Secondary merchant location or detail, or Unknown',
      nullable: true,
    },
    category: {
      type: SchemaType.STRING,
      description: 'Expense category such as Fuel, Food, Transfer',
    },
    paymentMethod: {
      type: SchemaType.STRING,
      description: 'card, account, wallet, or Unknown',
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

const SYSTEM_PROMPT = `You parse Pakistani bank SMS and email alerts into structured transaction JSON.

Rules:
- Amounts must be numbers without commas (e.g. 5990.00 not "5,990.00").
- Currency is usually PKR unless clearly stated otherwise.
- type must be lowercase "debit" or "credit".
- Dates must use ISO format: transactionDate as YYYY-MM-DD, transactionTime as ISO 8601 with +05:00 for Pakistan.
- Use "Unknown" for missing merchantDetails, branch, bank, or paymentMethod when not inferable.
- accountId should preserve masking from the message (e.g. xxx1215).
- externalIdType: use tid for TID, ref for reference numbers, stan for STAN, unknown otherwise.
- category: infer from merchant (PSO/Shell/Total → Fuel, McDonald's/KFC → Food, ATM → Cash Withdrawal).
- parseConfidence: 0.0-1.0 based on how clearly fields were extracted.

Examples:

Input: PKR 5,990.00 charged at PSO RANGERS>LAH for card used, from A/C xxx1215 (DHA PHASE VIII BR LHR) on 06-Jul-2026 at 11:27 TID:387522
Output: {"amount":5990,"currency":"PKR","type":"debit","merchant":"PSO RANGERS","merchantDetails":"LAH","category":"Fuel","paymentMethod":"card","bank":"Unknown","accountId":"xxx1215","branch":"DHA PHASE VIII BR LHR","transactionTime":"2026-07-06T11:27:00+05:00","transactionDate":"2026-07-06","externalId":"387522","externalIdType":"tid","parseConfidence":0.95}

Input: Your A/C 1234-5678901-02 has been debited with PKR 15,000.00 on 05-Jul-2026. Ref: FT2523456789. Avl Bal PKR 250,000.00
Output: {"amount":15000,"currency":"PKR","type":"debit","merchant":"Unknown","merchantDetails":null,"category":"Transfer","paymentMethod":"account","bank":"Unknown","accountId":"1234-5678901-02","branch":null,"transactionTime":"2026-07-05T00:00:00+05:00","transactionDate":"2026-07-05","externalId":"FT2523456789","externalIdType":"ref","parseConfidence":0.85}

Input: PKR 2,500.00 credited to A/C xxx9876 on 04-Jul-2026. Info: Salary
Output: {"amount":2500,"currency":"PKR","type":"credit","merchant":"Salary","merchantDetails":null,"category":"Income","paymentMethod":"account","bank":"Unknown","accountId":"xxx9876","branch":null,"transactionTime":"2026-07-04T00:00:00+05:00","transactionDate":"2026-07-04","externalId":null,"externalIdType":"unknown","parseConfidence":0.8}`;

export type ParseResult =
  | { ok: true; parsed: ParsedTransaction }
  | { ok: false; error: string; lowConfidence?: boolean };

function normalizeParsed(raw: Record<string, unknown>): ParsedTransaction {
  return {
    amount: Number(raw.amount),
    currency: String(raw.currency ?? 'PKR').toUpperCase(),
    type: String(raw.type ?? 'debit').toLowerCase() as ParsedTransaction['type'],
    merchant: String(raw.merchant ?? 'Unknown'),
    merchantDetails:
      raw.merchantDetails == null || raw.merchantDetails === 'Unknown'
        ? null
        : String(raw.merchantDetails),
    category: String(raw.category ?? 'Uncategorized'),
    paymentMethod: String(raw.paymentMethod ?? 'Unknown').toLowerCase(),
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
): Promise<string> {
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: modelName,
    systemInstruction: SYSTEM_PROMPT,
    generationConfig: {
      responseMimeType: 'application/json',
      responseSchema: PARSED_TRANSACTION_SCHEMA,
      temperature: 0.1,
    },
  });

  const result = await model.generateContent(
    `Parse this Pakistani bank message:\n\n${rawMessage}`,
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
): Promise<ParseResult> {
  let lastError = 'Unknown Gemini parse error';

  for (const modelName of GEMINI_MODELS) {
    try {
      const text = await generateWithModel(apiKey, modelName, rawMessage);
      const json = JSON.parse(text) as Record<string, unknown>;
      const parsed = normalizeParsed(json);

      if (parsed.parseConfidence < MIN_PARSE_CONFIDENCE) {
        return {
          ok: false,
          error: `Low parse confidence: ${parsed.parseConfidence}`,
          lowConfidence: true,
        };
      }

      return { ok: true, parsed };
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Unknown Gemini parse error';
      lastError = `[${modelName}] ${message}`;

      if (isRetryableModelError(message)) {
        await sleep(1500);
        continue;
      }

      return { ok: false, error: lastError };
    }
  }

  return { ok: false, error: lastError };
}
