import Foundation
import Network

/// Lightweight Local Background HTTP Server for OAuth callbacks & local webhooks
/// Runs 100% locally on 127.0.0.1 with ZERO remote server dependency.
public actor LocalCallbackServer {
    public static let shared = LocalCallbackServer()
    
    private var listener: NWListener?
    private var isRunning: Bool = false
    private var activePort: UInt16 = 8989
    
    private var onCodeReceived: ((String) -> Void)?
    private var continuation: CheckedContinuation<String, Error>?
    
    public init(port: UInt16 = 8989) {
        self.activePort = port
    }
    
    public enum ServerError: LocalizedError {
        case portUnavailable(UInt16)
        case stopped
        case accessDenied(String)
        case invalidRequest
        
        public var errorDescription: String? {
            switch self {
            case .portUnavailable(let port):
                return "本地端口 \(port) 被占用，请在设置中更换端口"
            case .stopped:
                return "本地后台服务已停止"
            case .accessDenied(let desc):
                return "飞书授权被拒绝: \(desc)"
            case .invalidRequest:
                return "收到的 HTTP 请求格式无效"
            }
        }
    }
    
    public var runningStatus: (isRunning: Bool, port: UInt16) {
        (isRunning, activePort)
    }
    
    /// Starts the background listener on 127.0.0.1
    public func start(port: UInt16 = 8989, codeHandler: ((String) -> Void)? = nil) throws {
        if isRunning && listener != nil && activePort == port {
            self.onCodeReceived = codeHandler
            return
        }
        
        stop()
        self.activePort = port
        self.onCodeReceived = codeHandler
        
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw ServerError.portUnavailable(port)
        }
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        let newListener = try NWListener(using: parameters, on: nwPort)
        
        newListener.newConnectionHandler = { [weak self] connection in
            Task {
                await self?.handleConnection(connection)
            }
        }
        
        newListener.stateUpdateHandler = { [weak self] state in
            Task {
                switch state {
                case .ready:
                    break
                case .failed:
                    await self?.stop()
                default:
                    break
                }
            }
        }
        
        newListener.start(queue: .global(qos: .userInitiated))
        self.listener = newListener
        self.isRunning = true
    }
    
    /// Waits asynchronously for a single code exchange
    public func waitForAuthorizationCode(timeoutSeconds: TimeInterval = 300) async throws -> String {
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.onCodeReceived = { [weak self] code in
                Task {
                    await self?.resumeContinuationWith(code: code)
                }
            }
        }
    }
    
    public func stop() {
        if let cont = continuation {
            continuation = nil
            cont.resume(throwing: ServerError.stopped)
        }
        listener?.cancel()
        listener = nil
        isRunning = false
        onCodeReceived = nil
    }
    
    private func resumeContinuationWith(code: String) {
        if let cont = continuation {
            continuation = nil
            cont.resume(returning: code)
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 4, maximumLength: 8192) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }
            Task {
                if let data = content, let requestString = String(data: data, encoding: .utf8) {
                    await self.processHttpRequest(requestString, connection: connection)
                }
            }
        }
    }
    
    private func processHttpRequest(_ request: String, connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse(connection: connection, html: htmlFailure(msg: "无效的请求格式"))
            return
        }
        
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, html: htmlFailure(msg: "无法解析请求"))
            return
        }
        
        let rawPath = parts[1]
        
        // Status check
        if rawPath.starts(with: "/status") {
            sendResponse(connection: connection, html: htmlStatus)
            return
        }
        
        // Callback parsing
        guard let url = URL(string: "http://127.0.0.1:\(activePort)" + rawPath) else {
            sendResponse(connection: connection, html: htmlFailure(msg: "无法解析请求 URL"))
            return
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        
        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            let errorDesc = queryItems.first(where: { $0.name == "error_description" })?.value ?? error
            sendResponse(connection: connection, html: htmlFailure(msg: "授权被拒绝: \(errorDesc)"))
            return
        }
        
        if let code = queryItems.first(where: { $0.name == "code" })?.value {
            sendResponse(connection: connection, html: htmlSuccess(code: code))
            onCodeReceived?(code)
            return
        }
        
        // Default root endpoint
        sendResponse(connection: connection, html: htmlRoot)
    }
    
    private func sendResponse(connection: NWConnection, html: String) {
        let bodyData = html.data(using: .utf8) ?? Data()
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: \(bodyData.count)\r\nConnection: close\r\n\r\n" + html
        let data = response.data(using: .utf8) ?? Data()
        
        connection.send(content: data, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
    
    // MARK: - HTML Templates
    
    private func htmlSuccess(code: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>Lark Native 本地授权成功</title>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body {
                    margin: 0; padding: 0; background: #0b0f19; color: #f8fafc;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                    display: flex; align-items: center; justify-content: center; height: 100vh;
                }
                .card {
                    background: rgba(30, 41, 59, 0.85); backdrop-filter: blur(24px);
                    border: 1px solid rgba(255, 255, 255, 0.12); border-radius: 20px;
                    padding: 40px; text-align: center; max-width: 440px;
                    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
                }
                .badge {
                    display: inline-block; background: rgba(51, 112, 255, 0.2);
                    color: #3370ff; padding: 4px 12px; border-radius: 20px;
                    font-size: 12px; font-weight: 600; margin-bottom: 16px;
                }
                .icon {
                    width: 64px; height: 64px; background: linear-gradient(135deg, #10b981, #059669);
                    border-radius: 50%; display: flex; align-items: center; justify-content: center;
                    margin: 0 auto 20px; box-shadow: 0 10px 25px rgba(16, 185, 129, 0.35);
                }
                h1 { margin: 0 0 10px; font-size: 22px; font-weight: 700; }
                p { margin: 0 0 20px; color: #94a3b8; font-size: 14px; line-height: 1.6; }
                .code-box {
                    background: rgba(15, 23, 42, 0.8); border: 1px dashed rgba(255,255,255,0.15);
                    padding: 10px; border-radius: 8px; font-family: monospace; font-size: 12px;
                    color: #cbd5e1; word-break: break-all; margin-bottom: 12px;
                }
            </style>
        </head>
        <body>
            <div class="card">
                <div class="badge">Lark Native 本地服务 (127.0.0.1)</div>
                <div class="icon">
                    <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                        <polyline points="20 6 9 17 4 12"></polyline>
                    </svg>
                </div>
                <h1>飞书授权成功！</h1>
                <p>本地后台服务已自动捕获授权码，Lark Native 正在完成 Token 换取与会话初始化。<br>您可以关闭此标签页并返回客户端。</p>
                <div class="code-box">Auth Code: \(code.prefix(12))...\(code.suffix(8))</div>
            </div>
        </body>
        </html>
        """
    }
    
    private func htmlFailure(msg: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>Lark Native 授权失败</title>
            <style>
                body {
                    margin: 0; padding: 0; background: #0b0f19; color: #f8fafc;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                    display: flex; align-items: center; justify-content: center; height: 100vh;
                }
                .card {
                    background: rgba(30, 41, 59, 0.85); backdrop-filter: blur(24px);
                    border: 1px solid rgba(239, 68, 68, 0.3); border-radius: 20px;
                    padding: 40px; text-align: center; max-width: 440px;
                    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
                }
                h1 { margin: 0 0 10px; font-size: 22px; font-weight: 700; color: #f87171; }
                p { margin: 0; color: #94a3b8; font-size: 14px; line-height: 1.6; }
            </style>
        </head>
        <body>
            <div class="card">
                <h1>授权未能完成</h1>
                <p>\(msg)</p>
            </div>
        </body>
        </html>
        """
    }
    
    private var htmlStatus: String {
        """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"><title>Lark Native 本地后台服务状态</title></head>
        <body style="background:#0b0f19;color:#fff;font-family:sans-serif;padding:40px;text-align:center;">
            <h2>🟢 Lark Native 本地回调服务正常运行中</h2>
            <p style="color:#94a3b8;">监听地址: <code>http://127.0.0.1:\(activePort)/callback</code></p>
            <p style="color:#64748b;">本服务仅在您的 Mac 本机内存中运行，无需任何远程服务器。</p>
        </body>
        </html>
        """
    }
    
    private var htmlRoot: String {
        """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"><title>Lark Native 本地服务</title></head>
        <body style="background:#0b0f19;color:#fff;font-family:sans-serif;padding:40px;text-align:center;">
            <h2>🐦 Lark Native 本地后台服务</h2>
            <p style="color:#94a3b8;">用于接收飞书 OAuth 2.0 本地授权回调与本机 Webhook 调度。</p>
        </body>
        </html>
        """
    }
}
