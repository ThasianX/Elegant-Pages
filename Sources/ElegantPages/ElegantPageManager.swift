// Kevin Li - 5:57 PM - 6/23/20

import Foundation
import SwiftUI

let screen = UIScreen.main.bounds
let window = UIApplication.shared.windows.filter { $0.isKeyWindow }.first

public protocol ElegantPagerDataSource {

    func view(for page: Int) -> AnyView

}

public protocol ElegantPagerDelegate {

    func willDisplay(page: Int)

}

enum PageState {

    case rearrange
    case scroll
    case completed

}

public enum ElegantPageTurnType {

    case regular(pageTurnDelta: CGFloat)
    case earlyCutoff(config: EarlyCutOffConfiguration)

    var pageTurnAnimation: Animation {
        switch self {
        case .regular:
            return .easeInOut
        case let .earlyCutoff(config):
            return config.pageTurnAnimation
        }
    }

}

public extension ElegantPageTurnType {

    static let regularDefault = Self.regular(pageTurnDelta: 0.5)
    static let earlyCutOffDefault = Self.earlyCutoff(config: .default)

}

public struct EarlyCutOffConfiguration {

    let scrollResistanceCutOff: CGFloat
    let pageTurnCutOff: CGFloat
    let pageTurnAnimation: Animation

}

extension EarlyCutOffConfiguration {

    static let `default` = EarlyCutOffConfiguration(
        scrollResistanceCutOff: 40,
        pageTurnCutOff: 80,
        pageTurnAnimation: .spring(response: 0.4, dampingFraction: 0.95))

}

class ElegantPagerManager: ObservableObject {

    @Published var currentPage: (index: Int, state: PageState)
    @Published var activeIndex: Int

    public let pageCount: Int
    public let pageTurnType: ElegantPageTurnType

    let maxPageIndex: Int

    public var datasource: ElegantPagerDataSource!
    public var delegate: ElegantPagerDelegate?

    init(startingPage: Int = 0, pageCount: Int, pageTurnType: ElegantPageTurnType) {
        guard pageCount > 0 else { fatalError("Error: pages must exist") }

        currentPage = (startingPage, .completed)
        self.pageCount = pageCount
        self.pageTurnType = pageTurnType
        maxPageIndex = (pageCount-1).clamped(to: 0...2)

        if startingPage == 0 {
            activeIndex = 0
        } else if startingPage == pageCount-1 {
            activeIndex = maxPageIndex
        } else {
            activeIndex = 1
        }
    }

    public func scroll(to page: Int) {
        currentPage = (page, .scroll)
    }

    // Only ever called for a page view with more than 3 pages
    func setCurrentPageToBeRearranged() {
        var currentIndex = currentPage.index

        if activeIndex == 1 {
            if currentIndex == 0 {
                // just scrolled from first page to second page
                currentIndex += 1
            } else if currentIndex == pageCount-1 {
                // just scrolled from last page to second to last page
                currentIndex -= 1
            } else {
                return
            }
        } else {
            if activeIndex == 0 {
                guard currentIndex != 0 else { return }
                // case where you're on the first page and you drag and stay on the first page
                currentIndex -= 1
            } else if activeIndex == 2 {
                guard currentIndex != pageCount-1 else { return }
                // case where you're on the first page and you drag and stay on the first page
                currentIndex += 1
            }
        }

        currentPage = (currentIndex, .rearrange)
    }

}

private extension ElegantPagerManager {

    var pageRange: ClosedRange<Int> {
        let startingPage: Int

        if currentPage.index == pageCount-1 {
            startingPage = (pageCount-3).clamped(to: 0...pageCount-1)
        } else {
            startingPage = (currentPage.index-1).clamped(to: 0...pageCount-1)
        }

        let trailingPage = (startingPage+2).clamped(to: 0...pageCount-1)

        return startingPage...trailingPage
    }

}

protocol ElegantPagerManagerDirectAccess {

    var pagerManager: ElegantPagerManager { get }

}

extension ElegantPagerManagerDirectAccess {

    var currentPage: (index: Int, state: PageState) {
        pagerManager.currentPage
    }

    var pageCount: Int {
        pagerManager.pageCount
    }

    var activeIndex: Int {
        pagerManager.activeIndex
    }

    var maxPageIndex: Int {
        pagerManager.maxPageIndex
    }

    var pageTurnType: ElegantPageTurnType {
        pagerManager.pageTurnType
    }

    var pageTurnAnimation: Animation {
        pageTurnType.pageTurnAnimation
    }

}

class ElegantSimplePagerManager: ObservableObject {

    @Published var currentPage: Int

    public let pageTurnType: ElegantPageTurnType

    public var delegate: ElegantPagerDelegate?

    init(startingPage: Int = 0, pageTurnType: ElegantPageTurnType) {
        currentPage = startingPage
        self.pageTurnType = pageTurnType
    }

    public func scroll(to page: Int) {
        withAnimation(pageTurnType.pageTurnAnimation) {
            currentPage = page
        }
        delegate?.willDisplay(page: page)
    }

}

protocol ElegantSimplePagerManagerDirectAccess {

    var pagerManager: ElegantSimplePagerManager { get }

}

extension ElegantSimplePagerManagerDirectAccess {

    var currentPage: Int {
        pagerManager.currentPage
    }

    var pageTurnType: ElegantPageTurnType {
        pagerManager.pageTurnType
    }

    var pageTurnAnimation: Animation {
        pageTurnType.pageTurnAnimation
    }

    var delegate: ElegantPagerDelegate? {
        pagerManager.delegate
    }

}


private class UpdateUIViewControllerBugFixClass { }

private enum ScrollDirection {

    case up
    case down
    case left
    case right

    var additiveFactor: Int {
        self == .up || self == .left ? -1 : 1
    }

}

struct ElegantVPageView: View, ElegantPagerManagerDirectAccess {

    @State private var translation: CGFloat = .zero
    @State private var isTurningPage = false

    @ObservedObject var pagerManager: ElegantPagerManager

    var bounces: Bool = false

    private var pagerHeight: CGFloat {
        screen.height * CGFloat(maxPageIndex+1)
    }

    private var pageOffset: CGFloat {
        -CGFloat(activeIndex) * screen.height
    }

    private var properTranslation: CGFloat {
        guard !bounces else { return translation }

        if (activeIndex == 0 && translation > 0) ||
            (activeIndex == maxPageIndex && translation < 0) {
            return 0
        }
        return translation
    }

    private var currentScrollOffset: CGFloat {
        pageOffset + properTranslation
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            ElegantPagerView(pagerManager: pagerManager, axis: .vertical)
                .frame(height: pagerHeight)
        }
        .frame(width: screen.width, height: screen.height, alignment: .top)
        .offset(y: currentScrollOffset)
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if abs(value.translation.width) > abs(value.translation.height) {
                        self.translation = .zero
                        return
                    }

                    withAnimation(self.pageTurnAnimation) {
                        self.translation = self.translationForOffset(value.translation.height)
                        self.turnPageIfNeededForChangingOffset(value.translation.height)
                    }
                }
                .onEnded { value in
                    withAnimation(self.pageTurnAnimation) {
                        self.turnPageIfNeededForEndOffset(value.translation.height)
                    }
                }
        )
    }

    private func translationForOffset(_ offset: CGFloat) -> CGFloat {
        switch pageTurnType {
        case .regular:
            return offset
        case let .earlyCutoff(config):
            guard !isTurningPage else { return 0 }
            return (offset / config.pageTurnCutOff) * config.scrollResistanceCutOff
        }
    }

    private func turnPageIfNeededForChangingOffset(_ offset: CGFloat) {
        switch pageTurnType {
        case .regular:
            return
        case let .earlyCutoff(config):
            guard !isTurningPage else { return }

            if offset > 0 && offset > config.pageTurnCutOff {
                guard currentPage.index != 0 else { return }

                scroll(direction: .up)
            } else if offset < 0 && offset < -config.pageTurnCutOff {
                guard currentPage.index != pageCount-1 else { return }

                scroll(direction: .down)
            }
        }
    }

    private func scroll(direction: ScrollDirection) {
        isTurningPage = true // Prevents user drag from continuing
        translation = .zero

        pagerManager.activeIndex = activeIndex + direction.additiveFactor
        pagerManager.setCurrentPageToBeRearranged()
    }

    private func turnPageIfNeededForEndOffset(_ offset: CGFloat) {
        translation = .zero

        switch pageTurnType {
        case .regular:
            let delta = offset / screen.height
            let newIndex = Int((CGFloat(activeIndex) - delta).rounded())
            pagerManager.activeIndex = newIndex.clamped(to: 0...maxPageIndex)
            pagerManager.setCurrentPageToBeRearranged()
        case .earlyCutoff:
            isTurningPage = false
        }
    }

}

struct ElegantHPageView: View, ElegantPagerManagerDirectAccess {

    @State private var translation: CGFloat = .zero
    @State private var isTurningPage = false

    @ObservedObject var pagerManager: ElegantPagerManager

    var bounces: Bool = false

    private var pagerWidth: CGFloat {
        screen.width * CGFloat(maxPageIndex+1)
    }

    private var pageOffset: CGFloat {
        -CGFloat(activeIndex) * screen.width
    }

    private var properTranslation: CGFloat {
        guard !bounces else { return translation }

        if (activeIndex == 0 && translation > 0) ||
            (activeIndex == maxPageIndex && translation < 0) {
            return 0
        }
        return translation
    }

    private var currentScrollOffset: CGFloat {
        pageOffset + properTranslation
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ElegantPagerView(pagerManager: pagerManager, axis: .horizontal)
                .frame(width: pagerWidth)
        }
        .frame(width: screen.width, height: screen.height, alignment: .leading)
        .offset(x: currentScrollOffset)
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if abs(value.translation.height) > abs(value.translation.width) {
                        self.translation = .zero
                        return
                    }

                    withAnimation(self.pageTurnAnimation) {
                        self.translation = self.translationForOffset(value.translation.width)
                        self.turnPageIfNeededForChangingOffset(value.translation.width)
                    }
                }
                .onEnded { value in
                    withAnimation(self.pageTurnAnimation) {
                        self.turnPageIfNeededForEndOffset(value.translation.width)
                    }
                }
        )
    }

    private func translationForOffset(_ offset: CGFloat) -> CGFloat {
        switch pageTurnType {
        case .regular:
            return offset
        case let .earlyCutoff(config):
            guard !isTurningPage else { return 0 }
            return (offset / config.pageTurnCutOff) * config.scrollResistanceCutOff
        }
    }

    private func turnPageIfNeededForChangingOffset(_ offset: CGFloat) {
        switch pageTurnType {
        case .regular:
            return
        case let .earlyCutoff(config):
            guard !isTurningPage else { return }

            if offset > 0 && offset > config.pageTurnCutOff {
                guard currentPage.index != 0 else { return }

                scroll(direction: .left)
            } else if offset < 0 && offset < -config.pageTurnCutOff {
                guard currentPage.index != pageCount-1 else { return }

                scroll(direction: .right)
            }
        }
    }

    private func scroll(direction: ScrollDirection) {
        isTurningPage = true // Prevents user drag from continuing
        translation = .zero

        pagerManager.activeIndex = activeIndex + direction.additiveFactor
        pagerManager.setCurrentPageToBeRearranged()
    }

    private func turnPageIfNeededForEndOffset(_ offset: CGFloat) {
        translation = .zero

        switch pageTurnType {
        case .regular:
            let delta = offset / screen.width
            let newIndex = Int((CGFloat(activeIndex) - delta).rounded())
            pagerManager.activeIndex = newIndex.clamped(to: 0...maxPageIndex)
            pagerManager.setCurrentPageToBeRearranged()
        case .earlyCutoff:
            isTurningPage = false
        }
    }

}

struct ElegantHSimplePageView<Pages>: View, ElegantSimplePagerManagerDirectAccess where Pages: View {

    @State private var translation: CGFloat = .zero

    @ObservedObject var pagerManager: ElegantSimplePagerManager

    public let pages: PageContainer<Pages>
    let pageCount: Int
    let bounces: Bool

    private var pageOffset: CGFloat {
        -CGFloat(currentPage) * screen.width
    }

    private var properTranslation: CGFloat {
        guard !bounces else { return translation }

        if (currentPage == 0 && translation > 0) ||
            (currentPage == pageCount-1 && translation < 0) {
            return 0
        }
        return translation
    }

    private var currentScrollOffset: CGFloat {
        pageOffset + properTranslation
    }

    init(pagerManager: ElegantSimplePagerManager,
         bounces: Bool = false,
         @PageViewBuilder builder: () -> PageContainer<Pages>) {
        self.pagerManager = pagerManager
        self.bounces = bounces
        let pages = builder()
        pageCount = pages.count
        self.pages = pages
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            pages
                .frame(width: screen.width, height: screen.height)
        }
        .frame(width: screen.width, height: screen.height, alignment: .leading)
        .offset(x: currentScrollOffset)
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if abs(value.translation.height) > abs(value.translation.width) {
                        self.translation = .zero
                        return
                    }

                    withAnimation(self.pageTurnAnimation) {
                        self.translation = self.translationForOffset(value.translation.width)
                        self.turnPageIfNeededForChangingOffset(value.translation.width)
                    }
                }
                .onEnded { value in
                    withAnimation(self.pageTurnAnimation) {
                        self.turnPageIfNeededForEndOffset(value.translation.width)
                    }
                }
        )
    }

    private func translationForOffset(_ offset: CGFloat) -> CGFloat {
        switch pageTurnType {
        case .regular:
            return offset
        case let .earlyCutoff(config):
            return (offset / config.pageTurnCutOff) * config.scrollResistanceCutOff
        }
    }

    private func turnPageIfNeededForChangingOffset(_ offset: CGFloat) {
        switch pageTurnType {
        case .regular:
            return
        case let .earlyCutoff(config):
            if offset > 0 && offset > config.pageTurnCutOff {
                guard currentPage != 0 else { return }

                scroll(direction: .left)
            } else if offset < 0 && offset < -config.pageTurnCutOff {
                guard currentPage != pageCount-1 else { return }

                scroll(direction: .right)
            }
        }
    }

    private func scroll(direction: ScrollDirection) {
        translation = .zero
        pagerManager.currentPage = currentPage + direction.additiveFactor
        delegate?.willDisplay(page: currentPage)
    }

    private func turnPageIfNeededForEndOffset(_ offset: CGFloat) {
        translation = .zero

        switch pageTurnType {
        case .regular:
            let delta = offset / screen.width
            let newIndex = Int((CGFloat(currentPage) - delta).rounded())
            pagerManager.currentPage = newIndex.clamped(to: 0...pageCount-1)
            delegate?.willDisplay(page: currentPage)
        case .earlyCutoff:
            ()
        }
    }

}

struct ElegantPagerView: UIViewControllerRepresentable, ElegantPagerManagerDirectAccess {

    typealias UIViewControllerType = ElegantPagerController

    // See https://stackoverflow.com/questions/58635048/in-a-uiviewcontrollerrepresentable-how-can-i-pass-an-observedobjects-value-to
    private let bugFix = UpdateUIViewControllerBugFixClass()

    @ObservedObject var pagerManager: ElegantPagerManager

    let axis: Axis

    func makeUIViewController(context: Context) -> ElegantPagerController {
        ElegantPagerController(manager: pagerManager, axis: axis)
    }

    func updateUIViewController(_ controller: ElegantPagerController, context: Context) {
        DispatchQueue.main.async {
            self.setProperPage(for: controller)
        }
        pagerManager.delegate?.willDisplay(page: currentPage.index)
    }

    private func setProperPage(for controller: ElegantPagerController) {
        switch currentPage.state {
        case .rearrange:
            controller.rearrange(manager: pagerManager) {
                self.setActiveIndex(1, animated: false, complete: true) // resets to center
            }
        case .scroll:
            let pageToTurnTo = currentPage.index > controller.previousPage ? maxPageIndex : 0

            if currentPage.index == 0 || currentPage.index == pageCount-1 {
                setActiveIndex(pageToTurnTo, animated: true, complete: true)
                controller.reset(manager: pagerManager)
            } else {
                // This first call to `setActiveIndex` is responsible for animating the page
                // turn to whatever page we want to scroll to
                setActiveIndex(pageToTurnTo, animated: true, complete: false)
                controller.reset(manager: pagerManager) {
                    self.setActiveIndex(1, animated: false, complete: true)
                }
            }
        case .completed:
            ()
        }
    }

    private func setActiveIndex(_ index: Int, animated: Bool, complete: Bool) {
        withAnimation(animated ? pageTurnAnimation : nil) {
            self.pagerManager.activeIndex = index
        }

        if complete {
            pagerManager.currentPage.state = .completed
        }
    }

}

class ElegantPagerController: UIViewController {

    private var controllers: [UIHostingController<AnyView>]
    private(set) var previousPage: Int

    let axis: Axis

    init(manager: ElegantPagerManager, axis: Axis) {
        self.axis = axis
        previousPage = manager.currentPage.index

        controllers = manager.pageRange.map { page in
            UIHostingController(rootView: manager.datasource.view(for: page))
        }
        super.init(nibName: nil, bundle: nil)

        controllers.enumerated().forEach { i, controller in
            addChild(controller)

            if axis == .horizontal {
                controller.view.frame = CGRect(x: screen.width * CGFloat(i),
                                               y: 0,
                                               width: screen.width,
                                               height: screen.height)
            } else {
                controller.view.frame = CGRect(x: 0,
                                               y: screen.height * CGFloat(i),
                                               width: screen.width,
                                               height: screen.height)
            }

            view.addSubview(controller.view)
            controller.didMove(toParent: self)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func rearrange(manager: ElegantPagerManager, completion: @escaping () -> Void) {
        defer {
            previousPage = manager.currentPage.index
        }

        // rearrange if...
        guard manager.currentPage.index != previousPage && // not same page
            (previousPage != 0 &&
                manager.currentPage.index != 0) && // not 1st or 2nd page
            (previousPage != manager.pageCount-1 &&
                manager.currentPage.index != manager.pageCount-1) // not last page or 2nd to last page
        else { return }

        rearrangeControllersAndUpdatePage(manager: manager)
        resetPagePositions()
        completion()
    }

    private func rearrangeControllersAndUpdatePage(manager: ElegantPagerManager) {
        if manager.currentPage.index > previousPage { // scrolled down
            controllers.append(controllers.removeFirst())
            controllers.last!.rootView = manager.datasource.view(for: manager.currentPage.index+1)
        } else { // scrolled up
            controllers.insert(controllers.removeLast(), at: 0)
            controllers.first!.rootView = manager.datasource.view(for: manager.currentPage.index-1)
        }
    }

    private func resetPagePositions() {
        controllers.enumerated().forEach { i, controller in
            if axis == .horizontal {
                controller.view.frame.origin = CGPoint(x: screen.width * CGFloat(i), y: 0)
            } else {
                controller.view.frame.origin = CGPoint(x: 0, y: screen.height * CGFloat(i))
            }
        }
    }

    func reset(manager: ElegantPagerManager, completion: (() -> Void)? = nil) {
        defer {
            previousPage = manager.currentPage.index
        }

        zip(controllers, manager.pageRange).forEach { controller, page in
            controller.rootView = manager.datasource.view(for: page)
        }

        completion?()
    }

}




