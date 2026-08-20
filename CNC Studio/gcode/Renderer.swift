//
//  Renderer.swift
//  CNC Studio
//
//  Created by Cristian Baluta on 20.08.2026.
//

import MetalKit
import simd

@MainActor
final class Renderer: NSObject, MTKViewDelegate {

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    private var vertexBuffer: MTLBuffer?

    private var viewportSize = SIMD2<Float>(1, 1)

    // MARK: Camera

    private var cameraRotation = simd_quatf(
        angle: 0,
        axis: SIMD3<Float>(0, 1, 0)
    )
    private var distance: Float = 6

    private var lastPanTranslation = CGPoint.zero

    private var axisVertices: [SIMD3<Float>] {
        // Axis lines + arrowheads
        let axisSize: Float = 3.0
        let arrowSize: Float = 0.25

        let vertices: [SIMD3<Float>] = [
            // X axis
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(axisSize, 0, 0),

            // X arrowhead
            SIMD3<Float>(axisSize, 0, 0),
            SIMD3<Float>(axisSize - arrowSize,  arrowSize, 0),

            SIMD3<Float>(axisSize, 0, 0),
            SIMD3<Float>(axisSize - arrowSize, -arrowSize, 0),

            // Y axis
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(0, axisSize, 0),

            // Y arrowhead
            SIMD3<Float>(0, axisSize, 0),
            SIMD3<Float>(arrowSize, axisSize - arrowSize, 0),

            SIMD3<Float>(0, axisSize, 0),
            SIMD3<Float>(-arrowSize, axisSize - arrowSize, 0),

            // Z axis
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(0, 0, axisSize),

            // Z arrowhead
            SIMD3<Float>(0, 0, axisSize),
            SIMD3<Float>( arrowSize, 0, axisSize - arrowSize),

            SIMD3<Float>(0, 0, axisSize),
            SIMD3<Float>(-arrowSize, 0, axisSize - arrowSize),
        ]

        return vertices
    }

    private var cubeVertices: [SIMD3<Float>] {

        let size: Float = 2.0
        let h = size / 2

        let vertices: [SIMD3<Float>] = [
            // ---------------------------------------------------------
            // Cube
            //
            // Bottom:
            // 0 ───── 1
            // │       │
            // 3 ───── 2
            //
            // Top:
            // 4 ───── 5
            // │       │
            // 7 ───── 6
            // ---------------------------------------------------------

            // Bottom face
            SIMD3<Float>(-h, -h, -h),
            SIMD3<Float>( h, -h, -h),

            SIMD3<Float>( h, -h, -h),
            SIMD3<Float>( h, -h,  h),

            SIMD3<Float>( h, -h,  h),
            SIMD3<Float>(-h, -h,  h),

            SIMD3<Float>(-h, -h,  h),
            SIMD3<Float>(-h, -h, -h),

            // Top face
            SIMD3<Float>(-h,  h, -h),
            SIMD3<Float>( h,  h, -h),

            SIMD3<Float>( h,  h, -h),
            SIMD3<Float>( h,  h,  h),

            SIMD3<Float>( h,  h,  h),
            SIMD3<Float>(-h,  h,  h),

            SIMD3<Float>(-h,  h,  h),
            SIMD3<Float>(-h,  h, -h),

            // Vertical edges
            SIMD3<Float>(-h, -h, -h),
            SIMD3<Float>(-h,  h, -h),

            SIMD3<Float>( h, -h, -h),
            SIMD3<Float>( h,  h, -h),

            SIMD3<Float>( h, -h,  h),
            SIMD3<Float>( h,  h,  h),

            SIMD3<Float>(-h, -h,  h),
            SIMD3<Float>(-h,  h,  h)
        ]

        return vertices
    }

    // MARK: Init

    override init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue()
        else {
            fatalError("Could not create Metal device")
        }

        self.device = device
        self.commandQueue = commandQueue

        // ---------------------------------------------------------
        // Metal pipeline
        // ---------------------------------------------------------

        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not load Metal library")
        }

        guard let vertexFunction =
                library.makeFunction(name: "line_vertex"),
              let fragmentFunction =
                library.makeFunction(name: "line_fragment")
        else {
            fatalError("Could not load Metal functions")
        }

        let descriptor = MTLRenderPipelineDescriptor()

        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction

        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            self.pipelineState =
                try device.makeRenderPipelineState(
                    descriptor: descriptor
                )
        } catch {
            fatalError(
                "Could not create pipeline: \(error)"
            )
        }

        super.init()


        // ---------------------------------------------------------
        // Geometry
        // ---------------------------------------------------------

        let vertices: [SIMD3<Float>] = axisVertices + cubeVertices

        guard let buffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<SIMD3<Float>>.stride * vertices.count,
            options: []
        ) else {
            fatalError("Could not create vertex buffer")
        }

        self.vertexBuffer = buffer
    }

    // MARK: Camera

    private func viewMatrix() -> float4x4 {

        let eye = cameraPosition()

        let target = SIMD3<Float>(
            0,
            0,
            0
        )

        let up = SIMD3<Float>(
            0,
            1,
            0
        )

        return float4x4(
            lookAt: eye,
            target: target,
            up: up
        )
    }

    private func cameraPosition() -> SIMD3<Float> {

        let basePosition = SIMD3<Float>(
            distance,
            distance,
            distance
        )

        return cameraRotation.act(basePosition)
    }

    private func projectionMatrix() -> float4x4 {

        let aspect =
            viewportSize.x /
            max(viewportSize.y, 1)

        let height = Float(distance)
        let width = height * aspect

        return float4x4(
            orthographicLeft: -width / 2,
            right: width / 2,
            bottom: -height / 2,
            top: height / 2,
            nearZ: -100,
            farZ: 100
        )
    }

    // MARK: Mouse orbit

    @objc
    func handlePan(
        _ gesture: NSPanGestureRecognizer
    ) {

        let translation =
            gesture.translation(in: gesture.view)

        if gesture.state == .began {
            lastPanTranslation = translation
            return
        }

        let dx = Float(
            translation.x -
            lastPanTranslation.x
        )

        let dy = Float(
            translation.y -
            lastPanTranslation.y
        )

        lastPanTranslation = translation

        let sensitivity: Float = 0.008

        // Horizontal rotation around world Y.
        let yawRotation = simd_quatf(
            angle: -dx * sensitivity,
            axis: SIMD3<Float>(0, 1, 0)
        )

        // Vertical rotation around the camera's local X axis.
        let cameraRight =
            cameraRotation.act(
                SIMD3<Float>(1, 0, 0)
            )

        let pitchRotation = simd_quatf(
            angle: -dy * sensitivity,
            axis: cameraRight
        )

        // Apply both rotations.
        cameraRotation =
            yawRotation *
            pitchRotation *
            cameraRotation

        cameraRotation =
            simd_normalize(cameraRotation)

        printCamera()
    }

    // MARK: Trackpad zoom

    @objc
    func handleMagnification(
        _ gesture: NSMagnificationGestureRecognizer
    ) {

        if gesture.state == .changed {

            let amount =
                Float(gesture.magnification)

            distance *= 1 - amount

            distance = max(
                1,
                min(30, distance)
            )

            gesture.magnification = 0

            printCamera()
        }
    }

    private func printCamera() {

        let position = cameraPosition()

        print("""
        
        Camera
        ─────────────────────
        position:
          x: \(position.x)
          y: \(position.y)
          z: \(position.z)

        distance:
          \(distance)

        quaternion:
          x: \(cameraRotation.imag.x)
          y: \(cameraRotation.imag.y)
          z: \(cameraRotation.imag.z)
          w: \(cameraRotation.real)

        ─────────────────────
        """)
    }

    // MARK: MTKViewDelegate

    func mtkView(
        _ view: MTKView,
        drawableSizeWillChange size: CGSize
    ) {

        viewportSize = SIMD2<Float>(
            Float(size.width),
            Float(size.height)
        )
    }

    func draw(in view: MTKView) {

        guard
            let drawable = view.currentDrawable,
            let descriptor =
                view.currentRenderPassDescriptor,
            let commandBuffer =
                commandQueue.makeCommandBuffer()
        else {
            return
        }

        let encoder =
            commandBuffer.makeRenderCommandEncoder(
                descriptor: descriptor
            )!

        encoder.setRenderPipelineState(
            pipelineState
        )

        var viewMatrix = viewMatrix()
        var projectionMatrix = projectionMatrix()

        encoder.setVertexBytes(
            &viewMatrix,
            length: MemoryLayout<float4x4>.stride,
            index: 1
        )

        encoder.setVertexBytes(
            &projectionMatrix,
            length: MemoryLayout<float4x4>.stride,
            index: 2
        )

        encoder.setVertexBuffer(
            vertexBuffer,
            offset: 0,
            index: 0
        )

        // X axis + arrowhead
        drawLine(encoder: encoder, vertexStart: 0, color: SIMD4<Float>(1, 0, 0, 1))
        drawLine(encoder: encoder, vertexStart: 2, color: SIMD4<Float>(1, 0, 0, 1))
        drawLine(encoder: encoder, vertexStart: 4, color: SIMD4<Float>(1, 0, 0, 1))

        // Y axis + arrowhead
        drawLine(encoder: encoder, vertexStart: 6, color: SIMD4<Float>(0, 1, 0, 1))
        drawLine(encoder: encoder, vertexStart: 8, color: SIMD4<Float>(0, 1, 0, 1))
        drawLine(encoder: encoder, vertexStart: 10, color: SIMD4<Float>(0, 1, 0, 1))

        // Z axis + arrowhead
        drawLine(encoder: encoder, vertexStart: 12, color: SIMD4<Float>(0, 0.4, 1, 1))
        drawLine(encoder: encoder, vertexStart: 14, color: SIMD4<Float>(0, 0.4, 1, 1))
        drawLine(encoder: encoder, vertexStart: 16, color: SIMD4<Float>(0, 0.4, 1, 1))

        // Cube
        let cubeColor = SIMD4<Float>(1, 1, 1, 1)

        for i in stride(from: 18, to: 42, by: 2) {
            drawLine(
                encoder: encoder,
                vertexStart: i,
                color: cubeColor
            )
        }

        encoder.endEncoding()

        commandBuffer.present(drawable)

        commandBuffer.commit()
    }

    private func drawLine(
        encoder: MTLRenderCommandEncoder,
        vertexStart: Int,
        color: SIMD4<Float>
    ) {

        var color = color

        encoder.setFragmentBytes(
            &color,
            length: MemoryLayout<SIMD4<Float>>.stride,
            index: 0
        )

        encoder.drawPrimitives(
            type: .line,
            vertexStart: vertexStart,
            vertexCount: 2
        )
    }
}

extension float4x4 {

    init(
        lookAt eye: SIMD3<Float>,
        target: SIMD3<Float>,
        up: SIMD3<Float>
    ) {

        let z =
            simd_normalize(eye - target)

        let x =
            simd_normalize(
                simd_cross(up, z)
            )

        let y =
            simd_cross(z, x)

        self.init(
            SIMD4<Float>(
                x.x, y.x, z.x, 0
            ),

            SIMD4<Float>(
                x.y, y.y, z.y, 0
            ),

            SIMD4<Float>(
                x.z, y.z, z.z, 0
            ),

            SIMD4<Float>(
                -simd_dot(x, eye),
                -simd_dot(y, eye),
                -simd_dot(z, eye),
                1
            )
        )
    }

    init(
        perspectiveFov fov: Float,
        aspect: Float,
        nearZ: Float,
        farZ: Float
    ) {

        let yScale =
            1 / tan(fov * 0.5)

        let xScale =
            yScale / aspect

        let zRange =
            farZ - nearZ

        self.init(
            SIMD4<Float>(
                xScale, 0, 0, 0
            ),

            SIMD4<Float>(
                0, yScale, 0, 0
            ),

            SIMD4<Float>(
                0,
                0,
                -(farZ + nearZ) / zRange,
                -1
            ),

            SIMD4<Float>(
                0,
                0,
                -(2 * farZ * nearZ) / zRange,
                0
            )
        )
    }
}

extension float4x4 {

    init(
        orthographicLeft left: Float,
        right: Float,
        bottom: Float,
        top: Float,
        nearZ: Float,
        farZ: Float
    ) {
        self.init(
            SIMD4<Float>(
                2 / (right - left),
                0,
                0,
                0
            ),

            SIMD4<Float>(
                0,
                2 / (top - bottom),
                0,
                0
            ),

            SIMD4<Float>(
                0,
                0,
                -2 / (farZ - nearZ),
                0
            ),

            SIMD4<Float>(
                -(right + left) / (right - left),
                -(top + bottom) / (top - bottom),
                -(farZ + nearZ) / (farZ - nearZ),
                1
            )
        )
    }
}

extension float4x4 {

    init(translation: SIMD3<Float>) {
        self = matrix_identity_float4x4

        columns.3 = SIMD4<Float>(
            translation.x,
            translation.y,
            translation.z,
            1
        )
    }
}
