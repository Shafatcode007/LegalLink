export interface RedactionResult {
  redacted: string;
  restore: (text: string) => string;
}

const PHONE_RE = /(?:\+?8801|01)[3-9]\d{8}\b/g;
const NID_RE = /\b(?:\d{10}|\d{13}|\d{17})\b/g;

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Redacts Bangladeshi phone numbers, NIDs, and caller-supplied names before any
 * external model call, keeping an ordered placeholder map for re-hydration.
 */
export function redactPii(text: string, names: string[] = []): RedactionResult {
  const buckets = new Map<string, string[]>();

  const remember = (token: string, original: string): void => {
    const existing = buckets.get(token);
    if (existing) existing.push(original);
    else buckets.set(token, [original]);
  };

  let redacted = text.replace(PHONE_RE, (match) => {
    remember('[PHONE]', match);
    return '[PHONE]';
  });

  redacted = redacted.replace(NID_RE, (match) => {
    remember('[NID]', match);
    return '[NID]';
  });

  names.forEach((name, index) => {
    if (!name) return;
    const token = `[NAME_${index + 1}]`;
    const pattern = new RegExp(escapeRegExp(name), 'g');
    redacted = redacted.replace(pattern, () => {
      remember(token, name);
      return token;
    });
  });

  const restore = (value: string): string => {
    let output = value;
    for (const [token, originals] of buckets) {
      const pattern = new RegExp(escapeRegExp(token), 'g');
      let cursor = 0;
      output = output.replace(pattern, () => originals[cursor++] ?? token);
    }
    return output;
  };

  return { redacted, restore };
}
