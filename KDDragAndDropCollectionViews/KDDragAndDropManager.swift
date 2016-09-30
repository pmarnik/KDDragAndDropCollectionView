//
//  KDDragAndDropManager.swift
//  KDDragAndDropCollectionViews
//
//  Created by Michael Michailidis on 10/04/2015.
//  Copyright (c) 2015 Karmadust. All rights reserved.
//

import UIKit

@objc protocol KDDraggable {
    func canDragAtPoint(point : CGPoint) -> Bool
    func representationImageAtPoint(point : CGPoint) -> UIView?
    func dataItemAtPoint(point : CGPoint) -> AnyObject?
    func dragDataItem(item : AnyObject) -> Void
    func dragSourceRect() -> CGRect
    optional func startDraggingAtPoint(point : CGPoint) -> Void
    optional func stopDragging() -> Void
    optional func willStopDragging() -> Void
}


@objc protocol KDDroppable {
    func canDropAtRect(rect : CGRect) -> Bool
    func willMoveItem(item : AnyObject, inRect rect : CGRect) -> Void
    func didMoveItem(item : AnyObject, inRect rect : CGRect) -> Void
    func didMoveOutItem(item : AnyObject) -> Void
    func dropDataItem(item : AnyObject, atRect : CGRect) -> Void
}


protocol KDDragAndDropManagerDelegate: class {
    func didStartDragging(manager: KDDragAndDropManager)
    func didEndDragging(manager: KDDragAndDropManager)
}

class KDDragAndDropManager: NSObject, UIGestureRecognizerDelegate {
    
    weak var delegate: KDDragAndDropManagerDelegate?
    
    private weak var canvas : UIView! = UIView()
    private var views : [UIView] = []
    private var longPressGestureRecogniser = UILongPressGestureRecognizer()
    
    
    struct Bundle {
        var offset : CGPoint = CGPointZero
        var sourceDraggableView : UIView
        var overDroppableView : UIView?
        var representationImageView : UIView
        var dataItem : AnyObject
    }
    var bundle : Bundle?
    
    init(canvas : UIView, collectionViews : [UIView]) {
        
        super.init()
        
        self.canvas = canvas
        
        self.longPressGestureRecogniser.delegate = self
        self.longPressGestureRecogniser.minimumPressDuration = 0.3
        self.longPressGestureRecogniser.addTarget(self, action: #selector(KDDragAndDropManager.updateForLongPress(_:)))
        
        self.canvas.addGestureRecognizer(self.longPressGestureRecogniser)
        self.views = collectionViews
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        
        for view in self.views.filter({ v -> Bool in v is KDDraggable})  {
            
                let draggable = view as! KDDraggable
                
                let touchPointInView = touch.locationInView(view)
                
                if draggable.canDragAtPoint(touchPointInView) == true {
                    
                    if let representation = draggable.representationImageAtPoint(touchPointInView) {
                        
                        representation.frame = self.canvas.convertRect(representation.frame, fromView: view)
                        
//                        representation.alpha = 0.7
                        
                        let pointOnCanvas = touch.locationInView(self.canvas)
                        
                        let offset = CGPointMake(pointOnCanvas.x - representation.center.x, pointOnCanvas.y - representation.center.y)
                        
                        if let dataItem : AnyObject = draggable.dataItemAtPoint(touchPointInView) {
                            
                            self.bundle = Bundle(
                                offset: offset,
                                sourceDraggableView: view,
                                overDroppableView : view is KDDroppable ? view : nil,
                                representationImageView: representation,
                                dataItem : dataItem
                            )
                            
                            return true
                    
                        } // if let dataIte...
                        
                
                    } // if let representation = dragg...
                   
           
            } // if draggable.canDragAtP...
            
        } // for view in self.views.fil...
        
        return false
        
    }
    
    
    
    
    func updateForLongPress(recogniser : UILongPressGestureRecognizer) -> Void {
        
        if let bundl = self.bundle {
            
            let pointOnCanvas = recogniser.locationInView(recogniser.view)
            let sourceDraggable : KDDraggable = bundl.sourceDraggableView as! KDDraggable
            let pointOnSourceDraggable = recogniser.locationInView(bundl.sourceDraggableView)
            
            switch recogniser.state {
                
                
            case .Began :
                self.canvas.addSubview(bundl.representationImageView)
                UIView.animateWithDuration(0.2, animations: {
                    let oldCenter = bundl.representationImageView.center
                    let newFrame = CGRectApplyAffineTransform(bundl.representationImageView.frame, CGAffineTransformMakeScale(1.31, 1.31))
                    bundl.representationImageView.frame = newFrame
                    bundl.representationImageView.center = oldCenter
                    
                    }, completion:  { _ in
                                           })
                sourceDraggable.startDraggingAtPoint?(pointOnSourceDraggable)
                
                self.delegate?.didStartDragging(self)

                
                
            case .Changed :
                
                // Update the frame of the representation image
     
                bundl.representationImageView.center = CGPointMake(pointOnCanvas.x - bundl.offset.x, pointOnCanvas.y - bundl.offset.y)
                
                var overlappingArea : CGFloat = 0.0
                
                var mainOverView : UIView?
                
                for view in self.views.filter({ v -> Bool in v is KDDroppable }) {
                 
                    let viewFrameOnCanvas = self.convertRectToCanvas(view.frame, fromView: view)
                    
                    
                    /*                ┌────────┐   ┌────────────┐
                    *                 │       ┌┼───│Intersection│
                    *                 │       ││   └────────────┘
                    *                 │   ▼───┘│
                    * ████████████████│████████│████████████████
                    * ████████████████└────────┘████████████████
                    * ██████████████████████████████████████████
                    */
                    
                    let intersectionNew = CGRectIntersection(bundl.representationImageView.frame, viewFrameOnCanvas).size
                    
                    
                    if (intersectionNew.width * intersectionNew.height) > overlappingArea {
                        
                        overlappingArea = intersectionNew.width * intersectionNew.width
                        
                        mainOverView = view
                    }

                    
                }
                
                if !(mainOverView is KDDroppable) {
                    mainOverView = bundle?.sourceDraggableView
                }
                
                if let droppable = mainOverView as? KDDroppable {
                    
                    let rect = self.canvas.convertRect(bundl.representationImageView.frame, toView: mainOverView)

                    
                    if droppable.canDropAtRect(rect) {
                        
                        if mainOverView != bundl.overDroppableView { // if it is the first time we are entering
                            
                            (bundl.overDroppableView as? KDDroppable)?.didMoveOutItem(bundl.dataItem)
                            droppable.willMoveItem(bundl.dataItem, inRect: rect)
                            
                        }
                        
                        // set the view the dragged element is over
                        self.bundle!.overDroppableView = mainOverView
                        
                        droppable.didMoveItem(bundl.dataItem, inRect: rect)
                        
                    }
                    
                    
                }
                
               
            case .Ended :
                
                var dropRect: CGRect?
                
                if bundl.sourceDraggableView != bundl.overDroppableView { // if we are actually dropping over a new view.
                    
                    if let droppable = bundl.overDroppableView as? KDDroppable {
                        
                        sourceDraggable.dragDataItem(bundl.dataItem)
                        
                        let rect = self.canvas.convertRect(bundl.representationImageView.frame, toView: bundl.overDroppableView)
                        
                        droppable.dropDataItem(bundl.dataItem, atRect: rect)
                        
                        dropRect = findDropRect()
                    }
                }
                
                if dropRect == nil {
                    dropRect = sourceDraggable.dragSourceRect()
                    dropRect = canvas.convertRect(dropRect!, fromView: (sourceDraggable as! UIView))
                }
                sourceDraggable.willStopDragging?()
                UIView.animateWithDuration(0.3, animations: {
                    bundl.representationImageView.frame = dropRect!
                    }, completion: { [weak self] (_) in
                        bundl.representationImageView.removeFromSuperview()
                        sourceDraggable.stopDragging?()
                        if let _self = self {
                            _self.delegate?.didEndDragging(_self)
                        }
                })
                
                
            default:
                break
                
            }
            
            
        } // if let bundl = self.bundle ...
        
        
        
    }
    
    private func findDropRect() -> CGRect? {
        guard let bundl = bundle, let targetView = bundl.overDroppableView else {
            return nil
        }
        let reprRect = self.canvas.convertRect(bundl.representationImageView.frame, toView: targetView)
        let targetRect = targetView.bounds
        var common = CGRectIntersection(reprRect, targetRect)
        common = targetView.convertRect(common, toView: canvas)
        return CGRect(x: common.midX, y: common.midY, width: 0, height: 0)
    }
    
    // MARK: Helper Methods 
    func convertRectToCanvas(rect : CGRect, fromView view : UIView) -> CGRect {
        
        var r : CGRect = rect
        
        var v = view
        
        while v != self.canvas {
            
            if let sv = v.superview {
                
                r.origin.x += sv.frame.origin.x
                r.origin.y += sv.frame.origin.y
                
                v = sv
                
                continue
            }
            break
        }
        
        return r
    }
   
}
