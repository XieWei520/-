using System.Diagnostics;

namespace DingTalkWindowsHost.Automation.Capture;

internal sealed record BoundedUiaTreeSnapshot<TNode>(
    IReadOnlyList<TNode> Nodes,
    bool TruncatedByNodeLimit,
    bool TruncatedByDepthLimit,
    bool TruncatedByTimeLimit,
    int SkippedChildren,
    TimeSpan Elapsed);

internal static class BoundedUiaTreeWalker
{
    public static BoundedUiaTreeSnapshot<TNode> Walk<TElement, TNode>(
        TElement root,
        int maxNodes,
        int maxDepth,
        TimeSpan timeBudget,
        Func<TElement, TNode> readNode,
        Func<TElement, IReadOnlyList<TElement>> readChildren)
    {
        ArgumentNullException.ThrowIfNull(readNode);
        ArgumentNullException.ThrowIfNull(readChildren);

        var stopwatch = Stopwatch.StartNew();
        var normalizedMaxNodes = Math.Max(1, maxNodes);
        var normalizedMaxDepth = Math.Max(0, maxDepth);
        var nodes = new List<TNode>(normalizedMaxNodes);
        var queue = new Queue<(TElement Element, int Depth)>();
        var skippedChildren = 0;
        var truncatedByDepthLimit = false;
        var truncatedByNodeLimit = false;
        var truncatedByTimeLimit = false;
        queue.Enqueue((root, 0));

        while (queue.Count > 0 && nodes.Count < normalizedMaxNodes)
        {
            if (stopwatch.Elapsed >= timeBudget)
            {
                truncatedByTimeLimit = true;
                break;
            }

            var (element, depth) = queue.Dequeue();
            nodes.Add(readNode(element));

            if (depth >= normalizedMaxDepth)
            {
                truncatedByDepthLimit |= queue.Count > 0;
                continue;
            }

            IReadOnlyList<TElement> children;
            try
            {
                children = readChildren(element);
            }
            catch (Exception ex) when (UiaExceptionClassifier.IsTransient(ex))
            {
                skippedChildren++;
                continue;
            }

            foreach (var child in children)
            {
                if (nodes.Count + queue.Count >= normalizedMaxNodes)
                {
                    truncatedByNodeLimit = true;
                    break;
                }

                queue.Enqueue((child, depth + 1));
            }
        }

        stopwatch.Stop();
        return new BoundedUiaTreeSnapshot<TNode>(
            Nodes: nodes,
            TruncatedByNodeLimit: truncatedByNodeLimit || (queue.Count > 0 && nodes.Count >= normalizedMaxNodes),
            TruncatedByDepthLimit: truncatedByDepthLimit,
            TruncatedByTimeLimit: truncatedByTimeLimit,
            SkippedChildren: skippedChildren,
            Elapsed: stopwatch.Elapsed);
    }
}
