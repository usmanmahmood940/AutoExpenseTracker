import { db } from './admin';
import {
  COLLECTIONS,
  DEFAULT_CATEGORIES,
  FALLBACK_CATEGORY_NAME,
  type Category,
  type CategorySeed,
} from './schema';

const CACHE_TTL_MS = 5 * 60 * 1000;

let cachedNames: string[] | null = null;
let cachedAt = 0;

/** Human-readable names for Gemini enum + validation (e.g. "Fuel"). */
export function defaultCategoryNames(): string[] {
  return DEFAULT_CATEGORIES.map((c) => c.name);
}

/** Resolve a model-returned category to one from the allowed list. */
export function resolveAllowedCategory(
  raw: string,
  allowedNames: string[],
): string {
  const trimmed = raw.trim();
  const exact = allowedNames.find((name) => name === trimmed);
  if (exact) {
    return exact;
  }

  const lower = trimmed.toLowerCase();
  const caseInsensitive = allowedNames.find(
    (name) => name.toLowerCase() === lower,
  );
  if (caseInsensitive) {
    return caseInsensitive;
  }

  return (
    allowedNames.find((name) => name === FALLBACK_CATEGORY_NAME) ??
    FALLBACK_CATEGORY_NAME
  );
}

/**
 * Load default category names from Firestore `categories`.
 * Falls back to the code seed list if empty or unavailable.
 * Cached briefly on warm Cloud Function instances.
 */
export async function loadDefaultCategoryNames(): Promise<string[]> {
  const now = Date.now();
  if (cachedNames && now - cachedAt < CACHE_TTL_MS) {
    return cachedNames;
  }

  try {
    const snapshot = await db
      .collection(COLLECTIONS.categories)
      .orderBy('sortOrder', 'asc')
      .get();

    const names = snapshot.docs
      .map((doc) => {
        const data = doc.data() as Partial<Category>;
        return typeof data.name === 'string' ? data.name.trim() : '';
      })
      .filter((name) => name.length > 0);

    if (names.length > 0) {
      cachedNames = names;
      cachedAt = now;
      return names;
    }
  } catch {
    // Fall through to code defaults (e.g. missing index / empty project).
  }

  const fallback = defaultCategoryNames();
  cachedNames = fallback;
  cachedAt = now;
  return fallback;
}

/**
 * Allowed category names for a user: global defaults + their custom categories.
 */
export async function loadAllowedCategoryNamesForUser(
  uid: string,
): Promise<string[]> {
  const defaults = await loadDefaultCategoryNames();
  try {
    const snapshot = await db
      .collection(COLLECTIONS.users)
      .doc(uid)
      .collection(COLLECTIONS.categories)
      .get();

    const custom = snapshot.docs
      .map((doc) => {
        const data = doc.data() as Partial<Category>;
        return typeof data.name === 'string' ? data.name.trim() : '';
      })
      .filter((name) => name.length > 0);

    if (custom.length === 0) {
      return defaults;
    }

    const seen = new Set(defaults.map((n) => n.toLowerCase()));
    const merged = [...defaults];
    for (const name of custom) {
      if (!seen.has(name.toLowerCase())) {
        seen.add(name.toLowerCase());
        merged.push(name);
      }
    }
    return merged;
  } catch {
    return defaults;
  }
}

/** Build Firestore documents for seeding `categories/{id}`. */
export function categorySeedDocuments(): Array<
  CategorySeed & { id: string }
> {
  return DEFAULT_CATEGORIES.map((c) => ({ ...c }));
}

/** Clear in-memory cache (tests / after seeding in the same process). */
export function clearCategoryCache(): void {
  cachedNames = null;
  cachedAt = 0;
}
