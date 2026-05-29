import { describe, expect, it } from 'vitest';
import { computeVirtualWindow, preservePrependAnchor } from './virtualList';

describe('computeVirtualWindow', () => {
  it('renders overscanned rows around the viewport', () => {
    expect(
      computeVirtualWindow({
        itemCount: 100,
        rowHeight: 72,
        scrollTop: 720,
        viewportHeight: 360,
        overscan: 2,
      }),
    ).toEqual({
      start: 8,
      end: 17,
      beforeHeight: 576,
      afterHeight: 5976,
    });
  });

  it('clamps empty lists', () => {
    expect(
      computeVirtualWindow({
        itemCount: 0,
        rowHeight: 72,
        scrollTop: 0,
        viewportHeight: 360,
        overscan: 2,
      }),
    ).toEqual({ start: 0, end: 0, beforeHeight: 0, afterHeight: 0 });
  });

  it('renders the last rows when scrollTop is beyond content height', () => {
    expect(
      computeVirtualWindow({
        itemCount: 10,
        rowHeight: 72,
        scrollTop: 99999,
        viewportHeight: 216,
        overscan: 2,
      }),
    ).toEqual({
      start: 5,
      end: 10,
      beforeHeight: 360,
      afterHeight: 0,
    });
  });
});

describe('preservePrependAnchor', () => {
  it('moves scrollTop by the inserted height', () => {
    expect(preservePrependAnchor({ previousScrollTop: 144, insertedCount: 10, rowHeight: 72 })).toBe(864);
  });
});
