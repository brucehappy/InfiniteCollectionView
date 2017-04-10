//
//  InfiniteCollectionView.swift
//  Pods
//
//  Created by hryk224 on 2015/10/17.
//
//

import UIKit

@objc public protocol InfiniteCollectionViewInternalsDelegate: class {
    @objc optional func infiniteCollectionView(_ collectionView: InfiniteCollectionView, didSelectItemActuallyAt actualIndexPath: IndexPath)
    @objc optional func infiniteCollectionView(_ collectionView: InfiniteCollectionView, willChangeIndexOffsetBy offset: Int)
    @objc optional func infiniteCollectionView(_ collectionView: InfiniteCollectionView, didChangeIndexOffsetBy offset: Int)
    @objc optional func infiniteCollectionViewWillBeginDragging(_ collectionView: InfiniteCollectionView)
    @objc optional func infiniteCollectionViewDidEndDragging(_ collectionView: InfiniteCollectionView)
    @objc optional func infiniteCollectionViewShouldHandleRotate(_ collectionView: InfiniteCollectionView) -> Bool
}

@objc public protocol InfiniteCollectionViewDataSource: class {
    @objc @available(*, deprecated, renamed: "number(ofItems:)")
    optional func numberOfItems(collectionView: UICollectionView) -> Int
    @objc @available(*, deprecated, renamed: "collectionView(_:dequeueForItemAt:cellForItemAt:)")
    optional func cellForItemAtIndexPath(collectionView: UICollectionView, dequeueIndexPath: NSIndexPath, indexPath: NSIndexPath) -> UICollectionViewCell
    func number(ofItems collectionView: UICollectionView) -> Int
    func collectionView(_ collectionView: UICollectionView, dequeueForItemAt dequeueIndexPath: IndexPath, cellForItemAt usableIndexPath: IndexPath) -> UICollectionViewCell
}

@objc public protocol InfiniteCollectionViewDelegate: class {
    @objc @available(*, deprecated, renamed: "infiniteCollectionView(_:didSelectItemAt:)")
    optional func didSelectCellAtIndexPath(collectionView: UICollectionView, indexPath: NSIndexPath)
    @objc @available(*, deprecated, renamed: "scrollView(_:pageIndex:)")
    optional func didUpdatePageIndex(index: Int)
    @objc optional func infiniteCollectionView(_ collectionView: UICollectionView, didSelectItemAt usableIndexPath: IndexPath)
    @objc optional func scrollView(_ scrollView: UIScrollView, pageIndex: Int)
}

open class InfiniteCollectionView: UICollectionView {
    open weak var infiniteDataSource: InfiniteCollectionViewDataSource?
    open weak var infiniteDelegate: InfiniteCollectionViewDelegate?
    open weak var infiniteInternalsDelegate: InfiniteCollectionViewInternalsDelegate?
    @available(*, deprecated, message: "It becomes unnecessary because it uses UICollectionViewFlowLayout.")
    open var cellWidth: CGFloat?
    fileprivate let dummyCount: Int = 3
    fileprivate let defaultIdentifier = "Cell"
    fileprivate(set) open var indexOffset: Int = 0
    fileprivate var pageIndex = 0
    fileprivate var scrollAnimationCompletion: (()->Void)? = nil
    fileprivate var fireOnDecelerate = false
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }
    override public init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        configure()
    }
    deinit {
        NotificationCenter.default.removeObserver(self, name: .UIDeviceOrientationDidChange, object: nil)
    }
    open func rotate(_ notification: Notification) {
        setContentOffset(CGPoint(x: CGFloat(pageIndex + indexOffset) * itemWidth, y: contentOffset.y), animated: false)
    }
    open override func selectItem(at indexPath: IndexPath?, animated: Bool, scrollPosition: UICollectionViewScrollPosition) {
        guard let indexPath = indexPath else { return }
        // Correct the input IndexPath
        let correctedIndexPath = IndexPath(row: correctedIndex(indexPath.item + indexOffset), section: 0)
        // Get the currently visible cell(s) - assumes a cell is visible
        guard let visibleCell = self.visibleCells.first else{
            return
        }
        // Index path of the cell - does not consider multiple cells on the screen at the same time
        guard let visibleIndexPath =  self.indexPath(for: visibleCell) else {
            return
        }
        let testIndexPath = IndexPath(row: correctedIndex(visibleIndexPath.item), section: 0)
        guard correctedIndexPath != testIndexPath else{
            return // Do not re-select the same cell
        }
        // Call supercase to select the correct IndexPath
        super.selectItem(at: correctedIndexPath, animated: animated, scrollPosition: scrollPosition)
    }
    open func datasourceIndexPathItem(forCollectionViewIndexPathItem item: Int) -> Int {
        return self.correctedIndex(item - self.indexOffset)
    }
    open func setContentOffset(_ contentOffset: CGPoint, animated: Bool, completion: (()->Void)?) {
        if self.contentOffset.equalTo(contentOffset) {
            completion?()
        } else {
            if animated {
                self.scrollAnimationCompletion = completion
            }
            self.setContentOffset(contentOffset, animated: animated)
            if !animated {
                completion?()
            }
        }
    }
    open func scrollRectToVisible(_ rect: CGRect, animated: Bool, completion: (()->Void)?) {
        if CGRect(origin: self.contentOffset, size: self.frame.size).contains(rect) {
            completion?()
        } else {
            if animated {
                self.scrollAnimationCompletion = completion
            }
            self.scrollRectToVisible(rect, animated: animated)
            if !animated {
                completion?()
            }
        }
    }
}

// MARK: - private
private extension InfiniteCollectionView {
    var itemWidth: CGFloat {
        guard let layout = collectionViewLayout as? UICollectionViewFlowLayout else { return 0 }
        return layout.itemSize.width + layout.minimumInteritemSpacing
    }
    var totalContentWidth: CGFloat {
        let numberOfCells: CGFloat = CGFloat(infiniteDataSource?.number(ofItems: self) ?? 0)
        return numberOfCells * itemWidth
    }
    func configure() {
        delegate = self
        dataSource = self
        register(UICollectionViewCell.self, forCellWithReuseIdentifier: defaultIdentifier)
        NotificationCenter.default.addObserver(self, selector: #selector(InfiniteCollectionView.handleRotate(_:)), name: .UIDeviceOrientationDidChange, object: nil)
    }
    func centerIfNeeded(_ scrollView: UIScrollView) {
        let currentOffset = contentOffset
        let centerX = (scrollView.contentSize.width - bounds.width) / 2
        let distFromCenter = centerX - currentOffset.x
        if fabs(distFromCenter) > (totalContentWidth / 4) {
            let cellcount = distFromCenter / itemWidth
            let shiftCells = Int((cellcount > 0) ? floor(cellcount) : ceil(cellcount))
            let offset = correctedIndex(shiftCells)
            infiniteInternalsDelegate?.infiniteCollectionView?(self, willChangeIndexOffsetBy: offset)
            let offsetCorrection = (abs(cellcount).truncatingRemainder(dividingBy: 1)) * itemWidth
            if centerX > contentOffset.x {
                contentOffset = CGPoint(x: centerX - offsetCorrection, y: currentOffset.y)
            } else {
                contentOffset = CGPoint(x: centerX + offsetCorrection, y: currentOffset.y)
            }
            indexOffset += offset
            reloadData()
            infiniteInternalsDelegate?.infiniteCollectionView?(self, didChangeIndexOffsetBy: offset)
        }
        let centerPoint = CGPoint(x: scrollView.frame.size.width / 2 + scrollView.contentOffset.x, y: scrollView.frame.size.height / 2 + scrollView.contentOffset.y)
        guard let indexPath = indexPathForItem(at: centerPoint) else { return }
        pageIndex = correctedIndex(indexPath.item - indexOffset)
        infiniteDelegate?.scrollView?(scrollView, pageIndex: pageIndex)
    }
    func correctedIndex(_ indexToCorrect: Int) -> Int {
        guard let numberOfItems = infiniteDataSource?.number(ofItems: self) else { return 0 }
        if numberOfItems > indexToCorrect && indexToCorrect >= 0 {
            return indexToCorrect
        }
        let countInIndex = Float(indexToCorrect) / Float(numberOfItems)
        let flooredValue = Int(floor(countInIndex))
        let offset = numberOfItems * flooredValue
        return indexToCorrect - offset
    }
    @objc func handleRotate(_ notification: Notification) {
        let shouldRotate = infiniteInternalsDelegate?.infiniteCollectionViewShouldHandleRotate?(self)
        if shouldRotate == nil || shouldRotate! == true {
            rotate(notification)
        }
    }
}

// MARK: - UICollectionViewDataSource
extension InfiniteCollectionView: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let numberOfItems = infiniteDataSource?.number(ofItems: collectionView) ?? 0
        return dummyCount * numberOfItems
    }
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = infiniteDataSource?.collectionView(collectionView, dequeueForItemAt: indexPath, cellForItemAt: IndexPath(item: correctedIndex(indexPath.item - indexOffset), section: 0)) else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: defaultIdentifier, for: indexPath)
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension InfiniteCollectionView: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        infiniteInternalsDelegate?.infiniteCollectionView?(self, didSelectItemActuallyAt: indexPath)
        infiniteDelegate?.infiniteCollectionView?(collectionView, didSelectItemAt: IndexPath(item: correctedIndex(indexPath.item - indexOffset), section: 0))
    }
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        infiniteInternalsDelegate?.infiniteCollectionViewWillBeginDragging?(self)
    }
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        fireOnDecelerate = decelerate
        if !fireOnDecelerate {
            infiniteInternalsDelegate?.infiniteCollectionViewDidEndDragging?(self)
        }
    }
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if fireOnDecelerate {
            fireOnDecelerate = false
            infiniteInternalsDelegate?.infiniteCollectionViewDidEndDragging?(self)
        }
    }
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        centerIfNeeded(scrollView)
    }
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if let completion = scrollAnimationCompletion {
            scrollAnimationCompletion = nil
            completion()
        }
    }
}
