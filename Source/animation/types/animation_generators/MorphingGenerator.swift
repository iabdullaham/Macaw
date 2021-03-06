//
//  MorphingGenerator.swift
//  Pods
//
//  Created by Victor Sukochev on 24/01/2017.
//
//

import UIKit

func addMorphingAnimation(_ animation: BasicAnimation, sceneLayer: CALayer, animationCache: AnimationCache, completion: @escaping (() -> ())) {
    guard let morphingAnimation = animation as? MorphingAnimation else {
        return
    }
    
    guard let shape = animation.node as? Shape else {
        return
    }
    
    let fromLocus = morphingAnimation.getVFunc()(0.0)
    let toLocus = morphingAnimation.getVFunc()(animation.autoreverses ? 0.5 : 1.0)
    let duration = animation.autoreverses ? animation.getDuration() / 2.0 : animation.getDuration()
    
    let layer = animationCache.layerForNode(shape, animation: animation, shouldRenderContent: false)
    
    // Creating proper animation
    let generatedAnim = pathAnimation(
        from:fromLocus,
        to:toLocus,
        duration: duration,
        renderTransform: layer.renderTransform!)
    
    generatedAnim.repeatCount = Float(animation.repeatCount)
    generatedAnim.timingFunction = caTimingFunction(animation.easing)
    generatedAnim.autoreverses = animation.autoreverses
    
    generatedAnim.completion = { finished in
        
        if !animation.manualStop {
            animation.progress = 1.0
            shape.form = morphingAnimation.getVFunc()(1.0)
        } else {
            shape.form = morphingAnimation.getVFunc()(animation.progress)
        }
        
        animationCache.freeLayer(shape)
        animation.completion?()
        
        if !finished {
            animationRestorer.addRestoreClosure(completion)
            return
        }
        
        completion()
    }
    
    generatedAnim.progress = { progress in
        
        let t = Double(progress)
        shape.form = morphingAnimation.getVFunc()(t)
        
        animation.progress = t
        animation.onProgressUpdate?(t)
    }
    
    layer.path = RenderUtils.toCGPath(fromLocus)
    
    // Stroke
    if let stroke = shape.stroke {
        if let color = stroke.fill as? Color {
            layer.strokeColor = RenderUtils.mapColor(color)
        } else {
            layer.strokeColor = UIColor.black.cgColor
        }
        
        layer.lineWidth = CGFloat(stroke.width)
        layer.lineCap = RenderUtils.mapLineCapToString(stroke.cap)
        layer.lineJoin = RenderUtils.mapLineJoinToString(stroke.join)
        layer.lineDashPattern = stroke.dashes.map{ NSNumber(value: $0)}
    } else {
        layer.strokeColor = UIColor.black.cgColor
        layer.lineWidth = 1.0
    }
    
    // Fill
    if let color = shape.fill as? Color {
        layer.fillColor = RenderUtils.mapColor(color)
    } else {
        layer.fillColor = UIColor.clear.cgColor
    }

    layer.add(generatedAnim, forKey: animation.ID)
    animation.removeFunc = {
        layer.removeAnimation(forKey: animation.ID)
    }
}

fileprivate func pathAnimation(from:Locus, to: Locus, duration: Double, renderTransform: CGAffineTransform) -> CAAnimation {
    
    var transform = renderTransform
    let fromPath = RenderUtils.toCGPath(from).copy(using: &transform)
    let toPath = RenderUtils.toCGPath(to).copy(using: &transform)
    
    let animation = CABasicAnimation(keyPath: "path")
    animation.fromValue = fromPath
    animation.toValue = toPath
    animation.duration = duration
    
    return animation
}
