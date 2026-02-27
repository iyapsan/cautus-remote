import Foundation
import NIOCore
import NIOSSH

/// NIO channel handler that reads SSH data from the child channel
/// and forwards it to an `AsyncStream<Data>` continuation.
///
/// Also notifies via `onClose` when the channel becomes inactive
/// (remote shell exit, network disconnect).
final class SSHDataHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = SSHChannelData
    typealias OutboundOut = SSHChannelData

    private let outputContinuation: AsyncStream<Data>.Continuation
    private let onClose: @Sendable () -> Void

    init(
        outputContinuation: AsyncStream<Data>.Continuation,
        onClose: @escaping @Sendable () -> Void = {}
    ) {
        self.outputContinuation = outputContinuation
        self.onClose = onClose
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let channelData = unwrapInboundIn(data)

        // Only forward standard channel data (not stderr for now)
        guard channelData.type == .channel, case .byteBuffer(var buffer) = channelData.data else {
            return
        }

        if let bytes = buffer.readBytes(length: buffer.readableBytes) {
            outputContinuation.yield(Data(bytes))
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        outputContinuation.finish()
        onClose()
        context.fireChannelInactive()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        // Channel errors terminate the stream
        outputContinuation.finish()
        onClose()
        context.close(promise: nil)
    }
}
