export interface VirtualWindowInput {
  itemCount: number;
  rowHeight: number;
  scrollTop: number;
  viewportHeight: number;
  overscan: number;
}

export interface VirtualWindow {
  start: number;
  end: number;
  beforeHeight: number;
  afterHeight: number;
}

export interface PreservePrependAnchorInput {
  previousScrollTop: number;
  insertedCount: number;
  rowHeight: number;
}

function clampNonNegative(value: number): number {
  return Number.isFinite(value) ? Math.max(0, value) : 0;
}

export function computeVirtualWindow(input: VirtualWindowInput): VirtualWindow {
  const itemCount = Math.floor(clampNonNegative(input.itemCount));
  const rowHeight = clampNonNegative(input.rowHeight);

  if (itemCount === 0 || rowHeight === 0) {
    return { start: 0, end: 0, beforeHeight: 0, afterHeight: 0 };
  }

  const scrollTop = clampNonNegative(input.scrollTop);
  const viewportHeight = clampNonNegative(input.viewportHeight);
  const overscan = Math.floor(clampNonNegative(input.overscan));
  const firstVisible = Math.floor(scrollTop / rowHeight);
  const visibleCount = Math.ceil(viewportHeight / rowHeight);
  const start = Math.max(0, firstVisible - overscan);
  const end = Math.min(itemCount, firstVisible + visibleCount + overscan);

  return {
    start,
    end,
    beforeHeight: start * rowHeight,
    afterHeight: Math.max(0, (itemCount - end) * rowHeight),
  };
}

export function preservePrependAnchor(input: PreservePrependAnchorInput): number {
  const previousScrollTop = clampNonNegative(input.previousScrollTop);
  const insertedCount = Math.floor(clampNonNegative(input.insertedCount));
  const rowHeight = clampNonNegative(input.rowHeight);

  return previousScrollTop + insertedCount * rowHeight;
}
