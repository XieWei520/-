using System.Net;
using System.Net.NetworkInformation;
using System.Runtime.InteropServices;

namespace DingTalkWindowsHost.Automation.StructuredSources;

internal static class StructuredSourceProbeSupport
{
    public static IReadOnlyList<LoopbackPortOwner> GetLoopbackPortOwners()
    {
        if (OperatingSystem.IsWindows())
        {
            return SafeGetWindowsLoopbackPortOwners();
        }

        var properties = IPGlobalProperties.GetIPGlobalProperties();
        return properties.GetActiveTcpListeners()
            .Where(static endpoint => IPAddress.IsLoopback(endpoint.Address))
            .Select(static endpoint => new LoopbackPortOwner(endpoint.Port, 0))
            .ToArray();
    }

    private static IReadOnlyList<LoopbackPortOwner> SafeGetWindowsLoopbackPortOwners()
    {
        try
        {
            return GetWindowsLoopbackPortOwners();
        }
        catch (InvalidOperationException)
        {
            return Array.Empty<LoopbackPortOwner>();
        }
        catch (OutOfMemoryException)
        {
            return Array.Empty<LoopbackPortOwner>();
        }
    }

    private static IReadOnlyList<LoopbackPortOwner> GetWindowsLoopbackPortOwners()
    {
        var bufferSize = 0;
        var result = GetExtendedTcpTable(
            tcpTable: IntPtr.Zero,
            tcpTableLength: ref bufferSize,
            sort: false,
            ipVersion: AfInet,
            tableClass: TcpTableClass.TcpTableOwnerPidListener,
            reserved: 0);

        if (result != ErrorInsufficientBuffer || bufferSize <= 0)
        {
            return Array.Empty<LoopbackPortOwner>();
        }

        var buffer = Marshal.AllocHGlobal(bufferSize);
        try
        {
            result = GetExtendedTcpTable(
                tcpTable: buffer,
                tcpTableLength: ref bufferSize,
                sort: false,
                ipVersion: AfInet,
                tableClass: TcpTableClass.TcpTableOwnerPidListener,
                reserved: 0);

            if (result != 0)
            {
                return Array.Empty<LoopbackPortOwner>();
            }

            var count = Marshal.ReadInt32(buffer);
            var rowPtr = IntPtr.Add(buffer, sizeof(int));
            var rowSize = Marshal.SizeOf<TcpRowOwnerPid>();
            var owners = new List<LoopbackPortOwner>(count);

            for (var index = 0; index < count; index++)
            {
                var row = Marshal.PtrToStructure<TcpRowOwnerPid>(
                    IntPtr.Add(rowPtr, index * rowSize));
                var localAddress = new IPAddress(row.LocalAddress);
                if (IPAddress.IsLoopback(localAddress))
                {
                    owners.Add(new LoopbackPortOwner(
                        Port: DecodeNetworkPort(row.LocalPort),
                        ProcessId: (int)row.OwningPid));
                }
            }

            return owners;
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }
    }

    private static int DecodeNetworkPort(uint networkPort)
    {
        return (int)IPAddress.NetworkToHostOrder((short)networkPort);
    }

    private const int AfInet = 2;
    private const int ErrorInsufficientBuffer = 122;

    private enum TcpTableClass
    {
        TcpTableOwnerPidListener = 3,
    }

    [StructLayout(LayoutKind.Sequential)]
    private readonly struct TcpRowOwnerPid
    {
        public readonly uint State;
        public readonly uint LocalAddress;
        public readonly uint LocalPort;
        public readonly uint RemoteAddress;
        public readonly uint RemotePort;
        public readonly uint OwningPid;
    }

    [DllImport("iphlpapi.dll", SetLastError = true)]
    private static extern int GetExtendedTcpTable(
        IntPtr tcpTable,
        ref int tcpTableLength,
        bool sort,
        int ipVersion,
        TcpTableClass tableClass,
        int reserved);
}
