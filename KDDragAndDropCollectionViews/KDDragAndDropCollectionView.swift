//
//  KDDragAndDropCollectionView.swift
//  KDDragAndDropCollectionViews
//
//  Created by Michael Michailidis on 10/04/2015.
//  Copyright (c) 2015 Karmadust. All rights reserved.
//

import UIKit



@objc public protocol KDDragAndDropCollectionViewDataSource : UICollectionViewDataSource {
    
    func collectionView(collectionView: UICollectionView, indexPathForDataItem dataItem: AnyObject) -> NSIndexPath?
    func collectionView(collectionView: UICollectionView, dataItemForIndexPath indexPath: NSIndexPath) -> AnyObject?
    
    func collectionView(collectionView: UICollectionView, moveDataItemFromIndexPath from: NSIndexPath, toIndexPath to : NSIndexPath) -> Void
    func collectionView(collectionView: UICollectionView, insertDataItem dataItem : AnyObject, atIndexPath indexPath: NSIndexPath) -> Void
    func collectionView(collectionView: UICollectionView, deleteDataItemAtIndexPath indexPath: NSIndexPath) -> Void
    
    func collectionView(collectionView: UICollectionView, canDropAtIndexPath indexPath: NSIndexPath) -> Bool
    
}

public class KDDragAndDropCollectionView: UICollectionView, KDDraggable, KDDroppable {

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public var draggingPathOfCellBeingDragged : NSIndexPath?
    var iDataSource : UICollectionViewDataSource?
    var iDelegate : UICollectionViewDelegate?
    
    var currentItem: AnyObject?
    var currentRect: CGRect?
    var timer: CADisplayLink?
    
    override public func awakeFromNib() {
        super.awakeFromNib()
     
    }
    
    override public init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
    
    }
    

    // MARK : KDDraggable
    public func canDragAtPoint(point : CGPoint) -> Bool {
        
        guard self.dataSource is KDDragAndDropCollectionViewDataSource else {
            return false
        }
        
        guard indexPathForItemAtPoint(point) != nil else {
            return false
        }
        return true
    }
    
    public func representationImageAtPoint(point : CGPoint) -> UIView? {
        
        var imageView : UIView?
        
        if let indexPath = self.indexPathForItemAtPoint(point) {
            
			if let cell = self.cellForItemAtIndexPath(indexPath) {
                cell.highlighted = true
				UIGraphicsBeginImageContextWithOptions(cell.bounds.size, cell.opaque, 0)
				cell.layer.renderInContext(UIGraphicsGetCurrentContext()!)
				let img = UIGraphicsGetImageFromCurrentImageContext()
				UIGraphicsEndImageContext()
				cell.highlighted = false
				imageView = UIImageView(image: img)
				
                
                let frame = cell.frame
                imageView?.frame = frame
			}
        }
        
        return imageView
    }
    
    public func dragSourceRect() -> CGRect {
        guard let currentIdx = draggingPathOfCellBeingDragged,
              let cell = cellForItemAtIndexPath(currentIdx) else {
            return CGRect.zero
        }
        return cell.frame
    }
    
    public func dataItemAtPoint(point : CGPoint) -> AnyObject? {
        
        var dataItem : AnyObject?
        
        if let indexPath = self.indexPathForItemAtPoint(point) {
            
            if let dragDropDS : KDDragAndDropCollectionViewDataSource = self.dataSource as? KDDragAndDropCollectionViewDataSource {
                
                dataItem = dragDropDS.collectionView(self, dataItemForIndexPath: indexPath)
                
            }
            
        }
        return dataItem
    }
    
    
    
    public func startDraggingAtPoint(point : CGPoint) -> Void {
        
        self.draggingPathOfCellBeingDragged = self.indexPathForItemAtPoint(point)
        
        
        self.reloadData()
        
    }
    
    public func willStopDragging() {
        stopTimer()
    }
    
    public func stopDragging() -> Void {
        if let idx = self.draggingPathOfCellBeingDragged {
            if let cell = self.cellForItemAtIndexPath(idx) {
                cell.hidden = false
            }
        }
        
        self.draggingPathOfCellBeingDragged = nil
        
        self.reloadData()
    }
    
    public func dragDataItem(item : AnyObject) -> Void {
        
        if let dragDropDataSource = self.dataSource as? KDDragAndDropCollectionViewDataSource {
            
            if let existngIndexPath = dragDropDataSource.collectionView(self, indexPathForDataItem: item) {
                
                dragDropDataSource.collectionView(self, deleteDataItemAtIndexPath: existngIndexPath)
                
                self.animating = true
                
                self.performBatchUpdates({ () -> Void in
                    
                    self.deleteItemsAtIndexPaths([existngIndexPath])
                    
                    }, completion: { complete -> Void in
                        
                        self.animating = false
                        
                        self.reloadData()
                        
                        
                })
                
                
            }
            
        }
        
    }
    
    // MARK : KDDroppable

    public func canDropAtRect(rect : CGRect) -> Bool {
        guard let dataSource = dataSource as? KDDragAndDropCollectionViewDataSource else {
            return false
        }
        guard let indexPath = indexPathForCellOverlappingRect(rect) else {
            return false
        }
        
        return dataSource.collectionView(self, canDropAtIndexPath: indexPath)
    }
    
    func indexPathForCellOverlappingRect( rect : CGRect) -> NSIndexPath? {
        return nearestDropableIndexPath(indexOfNearestVisibleCellForRect(rect))
    }
    
    
    private func indexOfNearestVisibleCellForRect(rect: CGRect) -> NSIndexPath {
        let cells = visibleCells()
        guard !cells.isEmpty else {
            return NSIndexPath(forRow: 0, inSection: 0)
        }
        let p = CGPoint(x: rect.midX, y: rect.midY)
        
        let (idx, _) = cells
            .filter({ (c: UICollectionViewCell) -> Bool in
                let area = c.frame.width * c.frame.height
                let rect = superview!.convertRect(c.frame, fromView: self)
                let overlap = CGRectIntersection(rect, frame)
                let overlapArea = overlap.width * overlap.height
                if overlapArea < area/3 {
                    return false
                }
                return true
            })
            .map({(c: UICollectionViewCell) -> (NSIndexPath, Double) in
            let center = c.center
            
            let distance: Double = Double(sqrt(pow(center.x - p.x, 2) + pow(center.y - p.y, 2)))
            let idx = indexPathForCell(c)
            return (idx!, distance)
        }).sort({$0.1 < $1.1}).first!
        return idx
    }
    
    private func nearestDropableIndexPath(indexPath: NSIndexPath?) -> NSIndexPath? {
        guard let indexPath = indexPath,
              let dataSource = self.dataSource as? KDDragAndDropCollectionViewDataSource else {
            return nil
        }
        var result = indexPath
        while(!dataSource.collectionView(self, canDropAtIndexPath: result)) {
            result = NSIndexPath(forItem: result.item - 1, inSection: 0)
            if (result.item < 0) {
                return nil
            }
        }

        
        return result
    }
    
    
    private var currentInRect : CGRect?
    public func willMoveItem(item : AnyObject, inRect rect : CGRect) -> Void {
        
        let dragDropDataSource = self.dataSource as! KDDragAndDropCollectionViewDataSource // its guaranteed to have a data source
        
        if let _ = dragDropDataSource.collectionView(self, indexPathForDataItem: item) { // if data item exists
            return
        }
        
        if let indexPath = self.indexPathForCellOverlappingRect(rect) {
            
            dragDropDataSource.collectionView(self, insertDataItem: item, atIndexPath: indexPath)
            
            self.draggingPathOfCellBeingDragged = indexPath
            
            self.animating = true
            
            self.performBatchUpdates({ () -> Void in
                
                    self.insertItemsAtIndexPaths([indexPath])
                
                }, completion: { complete -> Void in
                    
                    self.animating = false
                    
                    // if in the meantime we have let go
                    if self.draggingPathOfCellBeingDragged == nil {
                      
                        self.reloadData()
                    }
                    
                    
                })
            
            
        }
        
        currentInRect = rect
        
    }
    
    var isHorizontal : Bool {
        return (self.collectionViewLayout as? UICollectionViewFlowLayout)?.scrollDirection == .Horizontal
    }
    
    var animating: Bool = false
    
       
    public func didMoveItem(item : AnyObject, inRect rect : CGRect) -> Void {
        
        moveItem(item, atRect: rect)
        
        // Check Paging
        
        var normalizedRect = rect
        self.currentRect = rect
        self.currentItem = item
        normalizedRect.origin.x -= self.contentOffset.x
        normalizedRect.origin.y -= self.contentOffset.y
        
        
        currentInRect = normalizedRect
        self.currentRect = rect
        
        
        self.checkForEdge(rect)
//        self.checkForEdgesAndScroll(normalizedRect)
        
    }
    
    
    
    
    private func moveItem(item: AnyObject, atRect rect: CGRect) {
        let dragDropDS = self.dataSource as! KDDragAndDropCollectionViewDataSource // guaranteed to have a ds
        
        if  let existingIndexPath = dragDropDS.collectionView(self, indexPathForDataItem: item),
            let indexPath = self.indexPathForCellOverlappingRect(rect) {
            if indexPath.item != existingIndexPath.item {
                
                dragDropDS.collectionView(self, moveDataItemFromIndexPath: existingIndexPath, toIndexPath: indexPath)
                
                self.animating = true
                self.draggingPathOfCellBeingDragged = indexPath
                
                self.performBatchUpdates({ () -> Void in
                  
                    self.moveItemAtIndexPath(existingIndexPath, toIndexPath: indexPath)
                    
                    }, completion: { (finished) -> Void in
                        
                        self.animating = false
                })
                
                
                
                
            }
        }
    }
    
 
    
    func checkForEdge(rect: CGRect) {
        if outsideDistance(rect) > 0.2 {
            startTimer()
        } else {
            stopTimer()
        }
    }
    
    
    var paging : Bool = false
    func checkForEdgesAndScroll(rect : CGRect) -> Void {
        
        if paging == true {
            return
        }
        
        let currentRect : CGRect = CGRect(x: self.contentOffset.x, y: self.contentOffset.y, width: self.bounds.size.width, height: self.bounds.size.height)
        var rectForNextScroll : CGRect = currentRect
        
        if isHorizontal {
            
            let leftBoundary = CGRect(x: -30.0, y: 0.0, width: 30.0, height: self.frame.size.height)
            let rightBoundary = CGRect(x: self.frame.size.width, y: 0.0, width: 30.0, height: self.frame.size.height)
            
            if CGRectIntersectsRect(rect, leftBoundary) == true {
                rectForNextScroll.origin.x -= self.bounds.size.width * 0.5
                if rectForNextScroll.origin.x < 0 {
                    rectForNextScroll.origin.x = 0
                }
            }
            else if CGRectIntersectsRect(rect, rightBoundary) == true {
                rectForNextScroll.origin.x += self.bounds.size.width * 0.5
                if rectForNextScroll.origin.x > self.contentSize.width - self.bounds.size.width {
                    rectForNextScroll.origin.x = self.contentSize.width - self.bounds.size.width
                }
            }
            
        } else { // is vertical
            
            let topBoundary = CGRect(x: 0.0, y: -30.0, width: self.frame.size.width, height: 30.0)
            let bottomBoundary = CGRect(x: 0.0, y: self.frame.size.height, width: self.frame.size.width, height: 30.0)
            
            if CGRectIntersectsRect(rect, topBoundary) == true {
                
            }
            else if CGRectIntersectsRect(rect, bottomBoundary) == true {
                
            }
        }
        
        // check to see if a change in rectForNextScroll has been made
        if CGRectEqualToRect(currentRect, rectForNextScroll) == false {
            self.paging = true
            self.scrollRectToVisible(rectForNextScroll, animated: true)
            
            let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC)))
            dispatch_after(delayTime, dispatch_get_main_queue()) {
                self.paging = false
            }
            
        }
        
    }

    
    private func outsideDistance(rect: CGRect) -> CGFloat {
        var bounds = self.bounds
        bounds.origin = CGPoint.zero
        var outside: CGFloat = 0
        var translatedRect = rect
        translatedRect.origin.x -= contentOffset.x
        translatedRect.origin.y -= contentOffset.y
        if isHorizontal {
            let rightOutside =  translatedRect.maxX - bounds.width
            outside = max(-translatedRect.minX, rightOutside)/translatedRect.width
        } else {
            outside = max(-translatedRect.minY, translatedRect.maxY - bounds.height)/translatedRect.height
        }
        if (outside > 1) {
            outside = 1
        }
        return outside
    }
    
    
    func actionTimer() {
        let step = timerStepOffset()
        
        var nextOffset = contentOffset
        nextOffset.x += step.x
        nextOffset.y += step.y
        
        if  nextOffset.x < 0 ||
            nextOffset.x + frame.width > contentSize.width ||
            nextOffset.y < 0 ||
            nextOffset.y + frame.height > contentSize.height {
            stopTimer()
            return
        }
        
        setContentOffset(nextOffset, animated: false)
        self.currentRect?.origin.x += step.x
        self.currentRect?.origin.y += step.y
        
        self.setNeedsDisplay()
        if let currentItem = currentItem, currentRect = currentRect {
            moveItem(currentItem, atRect: currentRect)
            self.draggingPathOfCellBeingDragged = indexPathForCellOverlappingRect(currentRect)
        }
    }
    
    func timerStepOffset() -> CGPoint {
        guard let currentRect = currentRect else {
            return CGPoint.zero
        }
        
        var stepX: CGFloat = 0
        var stepY: CGFloat = 0
        let stepSize: CGFloat = 15 * outsideDistance(currentRect)
        let rect = superview!.convertRect(currentRect, fromView: self)
        if isHorizontal {
            if (rect.minX < frame.minX) {
                stepX = -stepSize
            }
            if rect.maxX > frame.maxX {
                stepX = stepSize
            }
        } else {
            if rect.minY < frame.minY {
                stepY = -stepSize
            }
            if rect.maxY > frame.maxY {
                stepY = stepSize
            }
        }
        
        return CGPoint(x: stepX, y: stepY)
    }
    
    
    private func startTimer() {
        guard timer == nil  else {
            return
        }
        timer = CADisplayLink(target: self, selector: #selector(actionTimer))
        timer!.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)

//        timer = NSTimer.scheduledTimerWithTimeInterval(1.0/30.0, target: self, selector: #selector(actionTimer), userInfo: nil, repeats: true)
        
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    public func didMoveOutItem(item : AnyObject) -> Void {
        stopTimer()
        
        guard let dragDropDataSource = self.dataSource as? KDDragAndDropCollectionViewDataSource,
              let existngIndexPath = dragDropDataSource.collectionView(self, indexPathForDataItem: item) else {
            
            return
        }
        
        dragDropDataSource.collectionView(self, deleteDataItemAtIndexPath: existngIndexPath)
        
        self.animating = true
        
        self.performBatchUpdates({ () -> Void in
            
            self.deleteItemsAtIndexPaths([existngIndexPath])
            
            }, completion: { (finished) -> Void in
                
                self.animating = false;
                
                self.reloadData()
                
            })
        
        
        if let idx = self.draggingPathOfCellBeingDragged {
            if let cell = self.cellForItemAtIndexPath(idx) {
                cell.hidden = false
            }
        }
        
        self.draggingPathOfCellBeingDragged = nil
        
        currentInRect = nil
    }
    
    
    public func dropDataItem(item : AnyObject, atRect : CGRect) -> Void {
        
        // show hidden cell
        if  let index = draggingPathOfCellBeingDragged,
            let cell = self.cellForItemAtIndexPath(index) {
            
            if (cell.hidden) {
                cell.alpha = 1.0
                cell.hidden = false
            }
            
            
            
        }
    
        currentInRect = nil
        
        self.draggingPathOfCellBeingDragged = nil
        
        self.reloadData()
        
    }
    
    
}
