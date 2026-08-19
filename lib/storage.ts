const KEY = "pesolita.wallet.v2";

/**
 * Everything lives on the device — the product promise is that no number leaves the phone.
 * Both directions are defensive: storage can be unavailable (private mode), full (a card photo
 * is a data URL and they are not small), or hold data written by an older build.
 */
export function load<T>(): T | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(KEY);
    return raw ? (JSON.parse(raw) as T) : null;
  } catch {
    return null;
  }
}

/** Returns false when the write failed, so the caller can tell the user rather than lose it silently. */
export function save<T>(value: T): boolean {
  if (typeof window === "undefined") return true;
  try {
    window.localStorage.setItem(KEY, JSON.stringify(value));
    return true;
  } catch {
    return false;
  }
}

export function clear(): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.removeItem(KEY);
  } catch {
    // Nothing to do — the data was never persisted in the first place.
  }
}
