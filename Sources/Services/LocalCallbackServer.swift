import Foundation
import Network

/// Lightweight On-Demand Local HTTP Server for OAuth callbacks
/// Starts ONLY during active authorization and stops immediately upon completion.
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
                return "本地端口 \(port) 被占用，无法启动临时回调服务"
            case .stopped:
                return "本地授权服务已结束"
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
    
    /// Starts the temporary listener on 127.0.0.1 and waits for callback
    public func startAndListen(port: UInt16 = 8989, timeoutSeconds: TimeInterval = 180) async throws -> String {
        stop()
        self.activePort = port
        
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw ServerError.portUnavailable(port)
        }
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        let newListener: NWListener
        do {
            newListener = try NWListener(using: parameters, on: nwPort)
        } catch {
            throw ServerError.portUnavailable(port)
        }
        
        self.listener = newListener
        self.isRunning = true
        
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            
            newListener.newConnectionHandler = { [weak self] connection in
                guard let self = self else { return }
                Task {
                    await self.handleConnection(connection)
                }
            }
            
            newListener.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                Task {
                    switch state {
                    case .ready:
                        break
                    case .failed:
                        await self.finishWithError(ServerError.portUnavailable(port))
                    default:
                        break
                    }
                }
            }
            
            newListener.start(queue: .global(qos: .userInitiated))
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
    
    private func finishWithCode(_ code: String) {
        if let cont = continuation {
            continuation = nil
            cont.resume(returning: code)
        }
        // Auto teardown server
        listener?.cancel()
        listener = nil
        isRunning = false
    }
    
    private func finishWithError(_ error: Error) {
        if let cont = continuation {
            continuation = nil
            cont.resume(throwing: error)
        }
        listener?.cancel()
        listener = nil
        isRunning = false
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
        
        guard let url = URL(string: "http://127.0.0.1:\(activePort)" + rawPath) else {
            sendResponse(connection: connection, html: htmlFailure(msg: "无法解析请求 URL"))
            return
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        
        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            let errorDesc = queryItems.first(where: { $0.name == "error_description" })?.value ?? error
            sendResponse(connection: connection, html: htmlFailure(msg: "授权被拒绝: \(errorDesc)"))
            finishWithError(ServerError.accessDenied(errorDesc))
            return
        }
        
        if let code = queryItems.first(where: { $0.name == "code" })?.value {
            sendResponse(connection: connection, html: htmlSuccess(code: code))
            finishWithCode(code)
            return
        }
        
        sendResponse(connection: connection, html: htmlFailure(msg: "未包含有效的 code 参数"))
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
            <title>Larkite 授权完成</title>
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
                <div class="badge">Larkite 临时授权服务</div>
                <div class="icon">
                    <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
                        <polyline points="20 6 9 17 4 12"></polyline>
                    </svg>
                </div>
                <h1>飞书授权成功！</h1>
                <p>已成功捕获授权码，临时服务已自动关闭。<br>您可以关闭此网页并返回 Larkite 客户端开始使用。</p>
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
            <title>Larkite 授权未完成</title>
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
}
