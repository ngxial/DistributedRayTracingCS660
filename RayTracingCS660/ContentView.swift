import SwiftUI
import MetalKit



struct ContentView: NSViewRepresentable {
    private let viewController: MetalViewController
    
    init(viewController: MetalViewController) {
        self.viewController = viewController
    }
    
    func makeNSView(context: Context) -> MTKView {
        print("ContentView: makeNSView called")
        print("MetalViewController class: \(MetalViewController.self)")
        
        let mtkView = MTKView(frame: .zero)
        mtkView.device = MTLCreateSystemDefaultDevice()
        if mtkView.device == nil {
            print("Failed to create Metal device in MTKViewRepresentable")
            return mtkView
        }
        
        // 設置 drawableSize
        let targetSize = CGSize(width: 800, height: 600)
        mtkView.drawableSize = targetSize
        print("ContentView makeNSView() Set drawable size to: \(targetSize.width) x \(targetSize.height)")
        
        viewController.setup(with: mtkView.device, view: mtkView)
        mtkView.delegate = viewController
        print("ContentView: MTKView delegate set to MetalViewController")
        
        NSLog("ContentView makeNSView() Get mtkView DrawableSize: width=%f, height=%f", mtkView.drawableSize.width, mtkView.drawableSize.height);
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        print("ContentView: updateNSView called")
    }
    
    func makeCoordinator() -> Coordinator {
        print("ContentView: makeCoordinator called")
        return Coordinator(viewController: viewController)
    }
    
    class Coordinator: NSObject {
        let viewController: MetalViewController
        
        init(viewController: MetalViewController) {
            self.viewController = viewController
            super.init()
            print("ContentView.Coordinator: Initialized with viewController: \(viewController)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewController: MetalViewController())
    }
}
