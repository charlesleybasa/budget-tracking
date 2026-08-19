/**
 * Images picked by the user are downscaled before they are stored.
 *
 * Everything lives in localStorage, which is a few megabytes for the whole origin — a single
 * modern phone photo is larger than that on its own. Re-encoding to a bounded JPEG keeps a
 * receipt or a QR readable while costing tens of kilobytes instead of megabytes.
 */
export class ImageError extends Error {}

const MAX_SOURCE_BYTES = 12 * 1024 * 1024;

export interface DownscaleOptions {
  /** Longest edge of the result, in px. */
  maxDim: number;
  quality: number;
}

export async function readImage(file: File, options: DownscaleOptions): Promise<string> {
  if (!file.type.startsWith("image/")) throw new ImageError("That's not an image.");
  if (file.size > MAX_SOURCE_BYTES) throw new ImageError("That image is too big — under 12MB please.");

  const source = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(new ImageError("Could not read that file."));
    reader.readAsDataURL(file);
  });

  const img = await new Promise<HTMLImageElement>((resolve, reject) => {
    const el = new Image();
    el.onload = () => resolve(el);
    el.onerror = () => reject(new ImageError("That image could not be opened."));
    el.src = source;
  });

  const scale = Math.min(1, options.maxDim / Math.max(img.naturalWidth, img.naturalHeight));
  const w = Math.max(1, Math.round(img.naturalWidth * scale));
  const h = Math.max(1, Math.round(img.naturalHeight * scale));

  const canvas = document.createElement("canvas");
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new ImageError("Could not process that image.");
  ctx.drawImage(img, 0, 0, w, h);

  try {
    return canvas.toDataURL("image/jpeg", options.quality);
  } catch {
    throw new ImageError("Could not process that image.");
  }
}

/** A receipt only has to stay legible, not printable. */
export const RECEIPT_OPTIONS: DownscaleOptions = { maxDim: 1400, quality: 0.72 };

/** A QR must survive being scanned off a screen, so it keeps more detail. */
export const QR_OPTIONS: DownscaleOptions = { maxDim: 900, quality: 0.88 };

/** Card art is displayed large but never zoomed. */
export const CARD_PHOTO_OPTIONS: DownscaleOptions = { maxDim: 1200, quality: 0.8 };
