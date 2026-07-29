import SwiftUI
import PencilKit

struct CanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var onChanged: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        let picker = context.coordinator.picker
        picker.setVisible(true, forFirstResponder: canvas)
        picker.addObserver(canvas)
        canvas.becomeFirstResponder()
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        if canvas.drawing != drawing { canvas.drawing = drawing }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasView
        let picker = PKToolPicker()
        init(_ parent: CanvasView) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
            parent.onChanged()
        }
    }
}
