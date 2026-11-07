using System;
using System.Threading;

// Harmless subprocess fixture: exercises output draining and process timeout.
class SlowTool
{
    static int Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "http")
        {
            var server = new System.Net.Sockets.TcpListener(System.Net.IPAddress.Loopback, 0);
            server.Start();
            Console.WriteLine(((System.Net.IPEndPoint)server.LocalEndpoint).Port);
            while (true)
            {
                using (var connection = server.AcceptTcpClient())
                using (var stream = connection.GetStream())
                {
                    var reader = new System.IO.StreamReader(stream);
                    string line;
                    do { line = reader.ReadLine(); } while (!string.IsNullOrEmpty(line));
                    Thread.Sleep(250);
                    byte[] response = System.Text.Encoding.ASCII.GetBytes("HTTP/1.1 200 OK\r\nContent-Length: 11\r\nConnection: close\r\n\r\ndownload ok");
                    stream.Write(response, 0, response.Length);
                }
            }
        }
        if (args.Length > 0 && args[0] == "hang") Thread.Sleep(10000);
        Console.Out.Write(new string('o', 65536));
        Console.Error.Write(new string('e', 65536));
        Thread.Sleep(350);
        Console.WriteLine("completed");
        return 0;
    }
}
