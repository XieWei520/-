using DingTalkWindowsHost.Automation.Capture;
using Xunit;

namespace DingTalkWindowsHost.Tests;

public sealed class BoundedUiaTreeWalkerTests
{
    [Fact]
    public void Walk_limits_nodes_breadth_first()
    {
        var root = new FakeNode(
            "root",
            new FakeNode("a"),
            new FakeNode("b"),
            new FakeNode("c"));

        var result = BoundedUiaTreeWalker.Walk(
            root,
            maxNodes: 2,
            maxDepth: 3,
            timeBudget: TimeSpan.FromSeconds(1),
            readNode: static node => node.Name,
            readChildren: static node => node.Children);

        Assert.Equal(new[] { "root", "a" }, result.Nodes);
        Assert.True(result.TruncatedByNodeLimit);
    }

    [Fact]
    public void Walk_limits_depth()
    {
        var root = new FakeNode(
            "root",
            new FakeNode(
                "a",
                new FakeNode("a-child")));

        var result = BoundedUiaTreeWalker.Walk(
            root,
            maxNodes: 10,
            maxDepth: 1,
            timeBudget: TimeSpan.FromSeconds(1),
            readNode: static node => node.Name,
            readChildren: static node => node.Children);

        Assert.Equal(new[] { "root", "a" }, result.Nodes);
        Assert.DoesNotContain("a-child", result.Nodes);
    }

    [Fact]
    public void Walk_skips_transient_child_errors()
    {
        var root = new FakeNode(
            "root",
            new FakeNode("a")
            {
                ThrowOnChildren = true,
            },
            new FakeNode("b"));

        var result = BoundedUiaTreeWalker.Walk(
            root,
            maxNodes: 10,
            maxDepth: 3,
            timeBudget: TimeSpan.FromSeconds(1),
            readNode: static node => node.Name,
            readChildren: static node => node.ThrowOnChildren
                ? throw new TimeoutException("slow provider")
                : node.Children);

        Assert.Equal(new[] { "root", "a", "b" }, result.Nodes);
        Assert.Equal(1, result.SkippedChildren);
    }

    private sealed class FakeNode
    {
        public FakeNode(string name, params FakeNode[] children)
        {
            Name = name;
            Children = children;
        }

        public string Name { get; }

        public IReadOnlyList<FakeNode> Children { get; }

        public bool ThrowOnChildren { get; init; }
    }
}
