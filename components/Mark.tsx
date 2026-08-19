/** The Pesolita star mark. */
export function Mark({ color = "#0b0b0c" }: { color?: string }) {
  return (
    <svg viewBox="0 0 24 24" width="100%" height="100%" aria-hidden="true" focusable="false">
      <path
        d="M12 1.6l2.5 6.1 6.1-2.5-2.5 6.1 6.1 2.5-6.1 2.5 2.5 6.1-6.1-2.5L12 24l-2.5-6.1-6.1 2.5 2.5-6.1L-0.2 13.8l6.1-2.5-2.5-6.1 6.1 2.5z"
        fill={color}
        transform="translate(1.2 -0.8) scale(.92)"
      />
    </svg>
  );
}
