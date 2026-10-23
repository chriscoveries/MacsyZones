//
// MacsyZones, macOS system utility for managing windows on your Mac.
// 
// https://macsyzones.com
// 
// Copyright © 2024, Oğuzhan Eroğlu <meowingcate@gmail.com> (https://meowingcat.io)
// 
// This file is part of MacsyZones.
// Licensed under GNU General Public License v3.0
// See LICENSE file.
//

import Cocoa
import ApplicationServices
import SwiftUI
import Accessibility
import CoreGraphics

var userLayouts: UserLayouts = .init()
var layoutSwitcherPanel: LayoutSwitcherPanel = .init()
var updateState: UpdateState = .init()
var toLeaveElement: AXUIElement?
var toLeaveSectionWindow: SectionWindow?
var toLeaveGridRect: NSRect?

var isFitting = false
var isEditing = false
var isQuickSnapping = false
var isSnapResizing = false
var isSwitcherUsed = false

var movingWindowInfo: (element: AXUIElement, windowId: UInt32)?
var isMovingAWindow = false
var draggedWindowElement: AXUIElement?
var draggedWindowInitialPosition: CGPoint?

var windowMovingOnScreen: NSScreen? = nil
var placedWindowMoveStartPosition: CGPoint?

func setIsFitting(_ fitting: Bool) {
    isFitting = fitting
}

func isSnapKeyPressed() -> Bool {
    guard appSettings.snapKey != "None" else { return false }
    
    let currentFlags = NSEvent.modifierFlags
    
    switch appSettings.snapKey {
    case "Shift":
        return currentFlags.contains(.shift)
    case "Control":
        return currentFlags.contains(.control)
    case "Command":
        return currentFlags.contains(.command)
    case "Option":
        return currentFlags.contains(.option)
    default:
        return false
    }
}

func checkSnapKeyOnWindowMoveStart() {
    if !macsyReady.isReady { return }

    if isSnapKeyPressed() && !isFitting {
        if appSettings.selectPerDesktopLayout {
            if let layoutName = spaceLayoutPreferences.getCurrent() {
                userLayouts.setCurrentLayout(name: layoutName)
            }
        }

        setIsFitting(true)

        let currentLayout = userLayouts.currentLayout

        switch currentLayout.layoutType {
            case .zone:
                currentLayout.layoutWindow.show()
            case .grid:
                currentLayout.gridLayoutWindow?.show()
                currentLayout.gridLayoutWindow?.setAnchorAtMousePosition()
        }
    }
}

let spaceLayoutPreferences = SpaceLayoutPreferences()

func onMouseDown(event: NSEvent) {
    draggedWindowElement = nil
    draggedWindowInitialPosition = nil
    toLeaveElement = nil
    toLeaveSectionWindow = nil
    toLeaveGridRect = nil

    if let preferredLayoutName = spaceLayoutPreferences.getCurrent() {
        userLayouts.currentLayoutName = preferredLayoutName
    }
}

func startEditing() {
    setIsFitting(false)
    isEditing = true
    userLayouts.currentLayout.layoutWindow.startEditing()
}

func stopEditing() {
    setIsFitting(false)
    isEditing = false
    userLayouts.currentLayout.materializedLayoutWindow?.stopEditing()
}

@discardableResult
func toggleEditing() -> Bool {
    setIsFitting(false)
    isEditing = !isEditing
    if isEditing {
        userLayouts.currentLayout.layoutWindow.startEditing()
    } else {
        userLayouts.currentLayout.materializedLayoutWindow?.stopEditing()
    }
    return isEditing
}

func getMenuBarHeight() -> CGFloat? {
    if let screen = NSScreen.main {
        let fullHeight = screen.frame.height
        let visibleHeight = screen.visibleFrame.height
        let menuBarHeight = fullHeight - visibleHeight
        return menuBarHeight
    }
    return nil
}

func getWindowSizeAndPosition(from windowID: UInt32) -> (CGSize?, CGPoint?) {
    let windowList = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as NSArray?
    
    guard let windowInfoList = windowList as? [[String: AnyObject]], let windowInfo = windowInfoList.first else {
        debugLog("Failed to retrieve window info")
        return (nil, nil)
    }
    
    if let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat] {
        let x = boundsDict["X"] ?? 0
        let y = boundsDict["Y"] ?? 0
        let width = boundsDict["Width"] ?? 0
        let height = boundsDict["Height"] ?? 0
        
        let size = CGSize(width: width, height: height)
        let position = CGPoint(x: x, y: y)
        return (size, position)
    } else {
        debugLog("Failed to retrieve window bounds")
        return (nil, nil)
    }
}

func getWindowID(from axElement: AXUIElement) -> UInt32? {
    var windowID: UInt32 = 0
    let result = _AXUIElementGetWindow(axElement, &windowID)

    if result == .success {
        return windowID
    } else {
        debugLog("Failed to get window ID, error code: \(result.rawValue)")
        return nil
    }
}

private var lastWindowMoveProcessTime: TimeInterval = 0
private let activeWindowMoveThrottle: TimeInterval = 1.0 / 120.0
private let idleWindowMoveThrottle: TimeInterval = 0.1

var shouldThrottleWindowMove: Bool {
    let now = ProcessInfo.processInfo.systemUptime
    let isDragging = CGEventSource.buttonState(.hidSystemState, button: .left)
    let minInterval = isDragging ? activeWindowMoveThrottle : idleWindowMoveThrottle

    if now - lastWindowMoveProcessTime < minInterval {
        return true
    }

    lastWindowMoveProcessTime = now
    return false
}

func onObserverNotification(observer: AXObserver, element: AXUIElement, notification: CFString, refcon: UnsafeMutableRawPointer?) {
    switch notification as String {
    case kAXWindowMovedNotification:
        if isEditing || isSnapResizing { return }
        if shouldThrottleWindowMove { return }

        Task { @MainActor in
            onWindowMoved(element: element)
        }

    case kAXWindowCreatedNotification:
        debugLog("New window created, starting to observe it.")
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return }
        Task { @MainActor in
            WindowObserverManager.shared.observeWindow(pid: pid, element: element)
        }

    case kAXUIElementDestroyedNotification:
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success,
              let windowID = getWindowID(from: element)
        else { return }
        Task { @MainActor in
            WindowObserverManager.shared.forgetWindow(pid: pid, windowID: windowID)
        }

    default:
        break
    }
}

let shakeCoolDown: TimeInterval = 0.75

var previousPosition: CGPoint?
var previousVelocity: CGPoint?
var previousTime: TimeInterval?
var lastShakeTime: TimeInterval = 0

let shakeClearInterval: TimeInterval = 0.25
var lastShakeClearTime: TimeInterval = 0

var shakeMagnitudeCount: CGFloat = 0

var justDidMouseUp = false

func getHoveredSectionWindow() -> SectionWindow? {
    debugLog("getHoveredSectionWindow(): isFitting = \(isFitting)")
    var hoveredSectionWindow: SectionWindow?
    
    guard getFocusedScreen() != nil else {
        for layout in userLayouts.layouts.values {
            for sectionWindow in layout.materializedLayoutWindow?.sectionWindows ?? [] {
                sectionWindow.isHovered = false
            }
        }
        
        return nil
    }
    
    let mouseLocation = NSEvent.mouseLocation
    
    if isFitting {
        if appSettings.snapHighlightStrategy != .centerProximity && appSettings.prioritizeCenterToSnap {
            for sectionWindow in userLayouts.currentLayout.layoutWindow.sectionWindows {
                let frame = sectionWindow.window.frame
                if abs(mouseLocation.x - frame.midX) < 50 &&
                   abs(mouseLocation.y - frame.midY) < 50 {
                    hoveredSectionWindow = sectionWindow
                    break
                }
            }
        }
        
        if hoveredSectionWindow == nil {
            // Select the best containing zone in one pass. Sorting all zones on
            // every move notification repeatedly recomputed their bounds.
            var bestScore = CGFloat.infinity
            for sectionWindow in userLayouts.currentLayout.layoutWindow.sectionWindows {
                // getBounds(for:) normalizes the window frame to screen
                // percentages, which the old hot path immediately undid.
                let frame = sectionWindow.window.frame
                guard mouseLocation.x > frame.minX, mouseLocation.x < frame.maxX,
                      mouseLocation.y > frame.minY, mouseLocation.y < frame.maxY else { continue }

                let score: CGFloat
                if appSettings.snapHighlightStrategy == .centerProximity {
                    let dx = mouseLocation.x - frame.midX
                    let dy = mouseLocation.y - frame.midY
                    score = dx * dx + dy * dy
                } else {
                    score = frame.width * frame.height
                }

                if score < bestScore {
                    bestScore = score
                    hoveredSectionWindow = sectionWindow
                }
            }
        }
    }

    // @Published triggers a SwiftUI update even when assigned the same value.
    // Window-move notifications can arrive 120 times per second.
    let shouldRaise = hoveredSectionWindow.map { !$0.isHovered } ?? false
    for sectionWindow in userLayouts.currentLayout.layoutWindow.sectionWindows {
        let isHovered = sectionWindow === hoveredSectionWindow
        if sectionWindow.isHovered != isHovered {
            sectionWindow.isHovered = isHovered
        }
    }

    if shouldRaise, let hoveredSectionWindow = hoveredSectionWindow {
        hoveredSectionWindow.window.orderFront(nil)
    }
    
    return hoveredSectionWindow
}

func onWindowMoved(element: AXUIElement) {
    guard macsyReady.isReady else { return }

    if let movingOnScreen = windowMovingOnScreen {
        if let screen = getFocusedScreen(), screen != movingOnScreen {
            movingWindowInfo = (element: element, windowId: getWindowID(from: element) ?? 0)
            windowMovingOnScreen = screen
            
            for layout in userLayouts.layouts.values {
                if layout.layoutType == .zone {
                    layout.materializedLayoutWindow?.isShown = false

                    for sectionWindow in layout.materializedLayoutWindow?.sectionWindows ?? [] {
                        sectionWindow.isHovered = false
                        sectionWindow.window.orderOut(nil)
                    }
                } else {
                    layout.materializedGridLayoutWindow?.hide()
                }
            }
            
            if appSettings.selectPerDesktopLayout {
                if let layoutName = spaceLayoutPreferences.getCurrent() {
                    userLayouts.currentLayoutName = layoutName
                }
            }
            
            if isFitting {
                let currentLayout = userLayouts.currentLayout
                switch currentLayout.layoutType {
                    case .zone:
                        currentLayout.layoutWindow.show()
                    case .grid:
                        isFitting = false
                    }
            } else if appSettings.enableLayoutSwitcher {
                layoutSwitcherPanel.move(to: screen)
            }

            toLeaveElement = nil
            toLeaveSectionWindow = nil
            toLeaveGridRect = nil

            return
        }
    }
    
    windowMovingOnScreen = getFocusedScreen()
    
    if appSettings.shakeToSnap && !isSwitcherUsed {
        let currentTime = Date().timeIntervalSince1970
        
        if lastShakeClearTime + shakeClearInterval >= currentTime {
            lastShakeTime = currentTime
            shakeMagnitudeCount = 0
        }
    }
    
    guard !isEditing,
          !isSnapResizing,
          !isQuickSnapping
    else { return }
    
    // WindowObserverManager registers moved notifications only after checking
    // AXRole and AXSubrole. Rechecking both on every drag costs two AX IPCs.
    
    if NSEvent.pressedMouseButtons & 1 != 0 {
        isMovingAWindow = true
        checkSnapKeyOnWindowMoveStart()
        
        if appSettings.enableLayoutSwitcher && !isFitting,
           let screen = getFocusedScreen() {
            layoutSwitcherPanel.showActualMode(on: screen)
        }
    }

    let currentLayout = userLayouts.currentLayout

    switch currentLayout.layoutType {
        case .zone:
            // Avoid creating all zone NSWindows during an ordinary drag.
            // The lazy layout lifecycle must stay lazy until snapping starts.
            if isFitting, let hoveredSectionWindow = getHoveredSectionWindow() {
                toLeaveElement = element
                toLeaveSectionWindow = hoveredSectionWindow
            }
        case .grid:
            if isFitting {
                currentLayout.gridLayoutWindow?.updateSelectionToMousePosition()
                toLeaveElement = element
                toLeaveGridRect = currentLayout.gridLayoutWindow?.getSelectionAXRect()
            }
    }
    
    guard let windowId = getWindowID(from: element) else {
        debugLog("Failed to get window ID")
        return
    }

    if NSEvent.pressedMouseButtons & 1 != 0 {
        // A new manual drag takes precedence over a pending snap correction.
        snapMoveGenerations.removeValue(forKey: windowId)
    }
    
    let isPlaced = PlacedWindows.isPlaced(windowId: windowId)
    let originalSize = OriginalWindowProperties.getWindowSize(for: windowId)
    
    if isPlaced && !justDidMouseUp &&
        (!appSettings.onlyFallbackToPreviousSizeWithUserEvent || (NSEvent.pressedMouseButtons & 0x1) != 0)
    {
        // Most dragged windows were never snapped. Ask AX for the position
        // only when a placed window needs its original-size fallback.
        var positionRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              let positionValue = positionRef,
              CFGetTypeID(positionValue) == AXValueGetTypeID() else { return }
        var position = CGPoint.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position) else { return }

        if placedWindowMoveStartPosition == nil {
            placedWindowMoveStartPosition = position
        }
        
        if let startPosition = placedWindowMoveStartPosition {
            let distanceMoved = sqrt(pow(position.x - startPosition.x, 2) +
                                     pow(position.y - startPosition.y, 2))
            
            if distanceMoved > 10 {
                placedWindowMoveStartPosition = nil
                PlacedWindows.unplace(windowId: windowId)
                
                if appSettings.fallbackToPreviousSize {
                    if let originalSize,
                       case let (currentSize?, currentPosition?) = getWindowSizeAndPosition(from: windowId)
                    {
                        let mouseLocation = NSEvent.mouseLocation
                        let relativeX = (mouseLocation.x - currentPosition.x) / currentSize.width

                        let widthDifference = currentSize.width - originalSize.width
                        if widthDifference != 0 {
                            let newXPosition = mouseLocation.x - (originalSize.width * relativeX)
                            
                            resizeAndMoveWindow(element: element,
                                                newPosition: CGPoint(x: newXPosition, y: currentPosition.y),
                                                newSize: originalSize)
                        }
                    } else if let originalSize {
                        resizeWindow(element: element, newSize: originalSize)
                        debugLog("Window resized to original size!")
                    }
                }
            } else {
                return
            }
        }
    }
    
    justDidMouseUp = false
    placedWindowMoveStartPosition = nil
    
    if isPlaced {
        return
    }
    
    if appSettings.shakeToSnap && !isSwitcherUsed {
        let isSnapKeyPressed = isSnapKeyPressed()

        guard !isSnapKeyPressed else { return }
        
        let dependingPosition = NSEvent.mouseLocation
        let currentTime = Date().timeIntervalSince1970

        if let previousPosition = previousPosition, let previousTime = previousTime {
            let deltaTime = currentTime - previousTime
            let deltaPosition = CGPoint(x: dependingPosition.x - previousPosition.x, y: dependingPosition.y - previousPosition.y)
            let currentVelocity = CGPoint(x: deltaPosition.x / CGFloat(deltaTime), y: deltaPosition.y / CGFloat(deltaTime))

            if let previousVelocity = previousVelocity {
                let oppositeDirectionOnX = (currentVelocity.x > 0 && previousVelocity.x < 0) || (currentVelocity.x < 0 && previousVelocity.x > 0)
                let oppositeDirectionOnY = (currentVelocity.y > 0 && previousVelocity.y < 0) || (currentVelocity.y < 0 && previousVelocity.y > 0)
                
                let deltaVelocity = CGPoint(x: currentVelocity.x - previousVelocity.x, y: currentVelocity.y - previousVelocity.y)
                let acceleration = CGPoint(x: deltaVelocity.x / CGFloat(deltaTime), y: deltaVelocity.y / CGFloat(deltaTime))
                let accelerationMagnitude = sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2))

                if (oppositeDirectionOnX || oppositeDirectionOnY) && accelerationMagnitude > appSettings.shakeAccelerationThreshold && currentTime - lastShakeTime > shakeCoolDown {
                    shakeMagnitudeCount += 1
                    
                    if shakeMagnitudeCount >= ((100000 - appSettings.shakeAccelerationThreshold) / 10000) {
                        lastShakeTime = currentTime
                        
                        if appSettings.selectPerDesktopLayout {
                            if let layoutName = spaceLayoutPreferences.getCurrent() {
                                userLayouts.setCurrentLayout(name: layoutName)
                            }
                        }
                        
                        isFitting = !isFitting
                        if isFitting {
                            userLayouts.currentLayout.show()
                        } else {
                            userLayouts.currentLayout.hide()
                        }
                        
                        shakeMagnitudeCount = 0
                        lastShakeTime = currentTime
                        lastShakeClearTime = currentTime
                    }
                }
            }

            previousVelocity = currentVelocity
        }

        previousPosition = dependingPosition
        previousTime = currentTime
    }
}

func getWindowTitle(from axElement: AXUIElement?) -> String? {
    guard let axElement = axElement else {
        return nil
    }
    
    var titleRef: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(axElement, kAXTitleAttribute as CFString, &titleRef)
    
    guard result == .success, let title = titleRef as? String else {
        debugLog("Failed to get window title, error code: \(result.rawValue)")
        return nil
    }
    
    return title
}

func getWindowDetails(element: AXUIElement) -> String {
    var details = "Window details: "
    
    var title: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
    if let windowTitle = title as? String {
        details += "Title: \(windowTitle)"
    } else {
        details += "Title: Unknown"
    }
    
    return details
}

// A newer snap must supersede a delayed correction for the same window.
private var snapMoveGenerations: [UInt32: UUID] = [:]

func resizeAndMoveWindow(element: AXUIElement, newPosition: CGPoint, newSize: CGSize, retries: Int = 0, useFallback: Bool = true) {
    /*
     * Fix macOS bug!
     * --------------
     * macOS has a bug, when you move & resize a window downward, the window is not being resized correctly.
     * This code fixes this buggy behavior of macOS 😇
     */
    if NSScreen.screens.count > 1 {
        var sizeValue = CGSize(width: newSize.width, height: newSize.height - 10)
        if let sizeAXValue = AXValueCreate(.cgSize, &sizeValue) {
            let result = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeAXValue)
            
            if result != .success {
                debugLog("Failed to set window size, error code: \(result.rawValue)")
                debugLog(getWindowDetails(element: element))
            }
        }
    }
    
    let windowId = getWindowID(from: element)
    let generation = UUID()
    if let windowId {
        snapMoveGenerations[windowId] = generation
    }
    
    var positionValue = newPosition
    var lastPositionResult: AXError = .failure
    if let positionAXValue = AXValueCreate(.cgPoint, &positionValue) {
        lastPositionResult = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionAXValue)
    }
    
    var sizeValue = newSize
    var lastSizeResult: AXError = .failure
    if let sizeAXValue = AXValueCreate(.cgSize, &sizeValue) {
        lastSizeResult = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeAXValue)
    }

    if (lastPositionResult != .success || lastSizeResult != .success) && useFallback {
        debugLog("Snap operation failed (position: \(lastPositionResult.rawValue), size: \(lastSizeResult.rawValue))")

        // A focused-window fallback can move an unrelated window if focus changed.
        var pid: pid_t = 0
        if let windowId,
           AXUIElementGetPid(element, &pid) == .success,
           let freshElement = retrieveFreshWindowElement(for: windowId, pid: pid) {
            resizeAndMoveWindow(element: freshElement, newPosition: newPosition, newSize: newSize, retries: retries, useFallback: false)
            return
        }
    }

    // Wait for the target application to apply the frame, then retry only if
    // its actual bounds are still different. Most snaps now take one write.
    if retries > 1, let windowId {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [element] in
            guard snapMoveGenerations[windowId] == generation else { return }

            if case let (currentSize?, currentPosition?) = getWindowSizeAndPosition(from: windowId),
               abs(currentPosition.x - newPosition.x) <= 1,
               abs(currentPosition.y - newPosition.y) <= 1,
               abs(currentSize.width - newSize.width) <= 1,
               abs(currentSize.height - newSize.height) <= 1 {
                snapMoveGenerations.removeValue(forKey: windowId)
                return
            }

            resizeAndMoveWindow(element: element, newPosition: newPosition,
                                newSize: newSize, retries: retries - 1,
                                useFallback: useFallback)
        }
    } else if let windowId {
        snapMoveGenerations.removeValue(forKey: windowId)
    }
}

extension NSScreen {
    var axY: CGFloat {
        let toppestY = NSScreen.screens.first!.frame.origin.y + NSScreen.screens.first!.frame.height
        return toppestY - (frame.origin.y + frame.height)
    }
}

func moveWindowToMatch(element: AXUIElement, targetWindow: NSWindow, targetScreen: NSScreen? = nil, sectionConfig: SectionConfig? = nil, retries: Int = 10) {
    let targetRect: NSRect
    if let targetScreen, let sectionConfig {
        targetRect = sectionConfig.getAXRect(on: targetScreen)
    } else {
        // Zone windows are borderless. Their AppKit frame is authoritative even
        // when hidden; querying WindowServer for an off-screen overlay can fail.
        guard let primaryTop = NSScreen.screens.first?.frame.maxY else { return }
        let frame = targetWindow.frame
        targetRect = NSRect(x: frame.minX, y: primaryTop - frame.maxY,
                            width: frame.width, height: frame.height)
    }

    resizeAndMoveWindow(element: element,
                        newPosition: targetRect.origin,
                        newSize: targetRect.size,
                        retries: retries)
}

func resizeWindow(element: AXUIElement, newSize: CGSize, useFallback: Bool = true) {
    var sizeValue = newSize
    let sizeAXValue = AXValueCreate(.cgSize, &sizeValue)
    
    if let sizeAXValue = sizeAXValue {
        let result = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeAXValue)
        
        if result != .success {
            debugLog("Failed to set window size, error code: \(result.rawValue)")

            var pid: pid_t = 0
            if useFallback,
               let windowId = getWindowID(from: element),
               AXUIElementGetPid(element, &pid) == .success,
               let freshElement = retrieveFreshWindowElement(for: windowId, pid: pid) {
                resizeWindow(element: freshElement, newSize: newSize, useFallback: false)
            }
        }
    }
}

func retrieveFreshWindowElement(for windowId: UInt32, pid: pid_t) -> AXUIElement? {
    debugLog("Attempting to retrieve fresh window element for window ID: \(windowId)")

    // The caller knows which app owns this window. Searching every running
    // app here multiplied slow cross-process AX requests during recovery.
    let appElement = AXUIElementCreateApplication(pid)
    var windowListRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowListRef) == .success,
          let windowList = windowListRef as? [AXUIElement] else { return nil }

    for window in windowList {
        if getWindowID(from: window) == windowId {
            debugLog("Successfully retrieved fresh window element for window ID: \(windowId)")
            return window
        }
    }
    
    debugLog("Failed to retrieve fresh window element for window ID: \(windowId)")
    
    return nil
}

func retrieveFreshWindowElementByTitle(title: String, approximatePosition: CGPoint? = nil, pid: pid_t? = nil) -> (element: AXUIElement, windowId: UInt32)? {
    debugLog("Attempting to retrieve fresh window element by title: \(title)")
    
    let runningApps = NSWorkspace.shared.runningApplications.filter {
        $0.activationPolicy == .regular && (pid == nil || $0.processIdentifier == pid)
    }
    
    var candidates: [(element: AXUIElement, windowId: UInt32, position: CGPoint?)] = []
    
    for app in runningApps {
        let pid = app.processIdentifier as pid_t
        let appElement = AXUIElementCreateApplication(pid)
        
        var windowListRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowListRef)
        
        if result != .success { continue }
        
        guard let windowList = windowListRef as? [AXUIElement] else { continue }
        
        for window in windowList {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
            
            if let windowTitle = titleValue as? String, windowTitle == title {
                if let windowId = getWindowID(from: window) {
                    var positionRef: CFTypeRef?
                    var windowPosition: CGPoint?
                    if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success {
                        var position: CGPoint = .zero
                        AXValueGetValue(positionRef as! AXValue, AXValueType.cgPoint, &position)
                        windowPosition = position
                    }
                    
                    candidates.append((element: window, windowId: windowId, position: windowPosition))
                }
            }
        }
    }
    
    if let approximatePosition = approximatePosition, !candidates.isEmpty {
        let closest = candidates.min { candidate1, candidate2 in
            guard let pos1 = candidate1.position, let pos2 = candidate2.position else {
                return candidate1.position != nil
            }
            let dist1 = sqrt(pow(pos1.x - approximatePosition.x, 2) + pow(pos1.y - approximatePosition.y, 2))
            let dist2 = sqrt(pow(pos2.x - approximatePosition.x, 2) + pow(pos2.y - approximatePosition.y, 2))
            return dist1 < dist2
        }
        
        if let match = closest {
            debugLog("Successfully retrieved fresh window element by title and position for: \(title)")
            return (element: match.element, windowId: match.windowId)
        }
    }
    
    if let first = candidates.first {
        debugLog("Successfully retrieved fresh window element by title for: \(title)")
        return (element: first.element, windowId: first.windowId)
    }
    
    debugLog("Failed to retrieve fresh window element by title: \(title)")
    
    return nil
}

func getFocusedWindowAXUIElement() -> AXUIElement? {
    guard let frontmostApp = NSWorkspace.shared.frontmostApplication else { return nil }
    
    let pid = frontmostApp.processIdentifier
    let focusedApp = AXUIElementCreateApplication(pid)
    
    var focusedWindow: AnyObject?
    let windowResult = AXUIElementCopyAttributeValue(focusedApp, kAXFocusedWindowAttribute as CFString, &focusedWindow)
    
    guard windowResult == .success else {
        debugLog("Failed to get focused window!")
        return nil
    }
    
    return focusedWindow as! AXUIElement?
}

func onMouseDragged(event: NSEvent) {
}

func onMouseUp(event: NSEvent) {
    guard macsyReady.isReady else { return }

    defer {
        draggedWindowElement = nil
        draggedWindowInitialPosition = nil
        toLeaveElement = nil
        toLeaveSectionWindow = nil
        toLeaveGridRect = nil
    }

    // Hide the layout switcher regardless of mode (actualMode or directMode).
    layoutSwitcherPanel.hide()

    movingWindowInfo = nil
    isMovingAWindow = false
    placedWindowMoveStartPosition = nil
    previousPosition = nil
    previousVelocity = nil
    previousTime = nil
    lastShakeTime = Date().timeIntervalSince1970 + 0.75

    guard !isQuickSnapping,
          isFitting
    else { return }

    if isEditing || isSnapResizing || isQuickSnapping {
        setIsFitting(false)
    }

    let currentLayout = userLayouts.currentLayout

    switch currentLayout.layoutType {
    case .zone:
        handleZoneMouseUp()
    case .grid:
        handleGridMouseUp()
    }
}

private func handleZoneMouseUp() {
    // Choose the zone under the release point. Keeping the last hovered zone
    // can snap a window after the cursor has already left every zone.
    toLeaveSectionWindow = getHoveredSectionWindow()

    // Mirror handleGridMouseUp: resolve the element from multiple fallback sources
    // so snap still works even if onWindowMoved didn't set toLeaveElement.
    toLeaveElement = toLeaveElement ?? draggedWindowElement ?? getFocusedWindowAXUIElement()

    guard let window = toLeaveElement else {
        setIsFitting(false)
        toLeaveElement = nil
        toLeaveSectionWindow = nil
        userLayouts.currentLayout.materializedLayoutWindow?.hide()
        return
    }
    guard let windowId = getWindowID(from: window) else {
        setIsFitting(false)
        toLeaveElement = nil
        toLeaveSectionWindow = nil
        userLayouts.currentLayout.materializedLayoutWindow?.hide()
        return
    }

    if let sectionWindow = toLeaveSectionWindow {
        if isFitting {
            OriginalWindowProperties.update(windowID: windowId)

            moveWindowToMatch(element: window, targetWindow: sectionWindow.window)

            if let (screenNumber, workspaceNumber) = SpaceLayoutPreferences.getCurrentScreenAndSpace() {
                PlacedWindows.place(windowId: windowId,
                                    screenNumber: screenNumber,
                                    workspaceNumber: workspaceNumber,
                                    layoutName: userLayouts.currentLayoutName,
                                    sectionNumber: sectionWindow.number,
                                    element: toLeaveElement!)
            }

            justDidMouseUp = true
        }

        setIsFitting(false)
        userLayouts.currentLayout.materializedLayoutWindow?.hide()
    } else {
        setIsFitting(false)
        toLeaveElement = nil
        toLeaveSectionWindow = nil
        userLayouts.currentLayout.materializedLayoutWindow?.hide()
    }
}

private func handleGridMouseUp() {
    let gridLayoutWindow = userLayouts.currentLayout.gridLayoutWindow

    gridLayoutWindow?.updateSelectionToMousePosition()
    toLeaveElement = toLeaveElement ?? draggedWindowElement ?? getFocusedWindowAXUIElement()
    toLeaveGridRect = gridLayoutWindow?.getSelectionAXRect()

    guard let window = toLeaveElement else {
        setIsFitting(false)
        toLeaveElement = nil
        toLeaveGridRect = nil
        gridLayoutWindow?.hide()
        return
    }
    guard let windowId = getWindowID(from: window) else {
        setIsFitting(false)
        toLeaveElement = nil
        toLeaveGridRect = nil
        gridLayoutWindow?.hide()
        return
    }
    guard let snapRect = toLeaveGridRect else {
        setIsFitting(false)
        toLeaveElement = nil
        toLeaveGridRect = nil
        gridLayoutWindow?.hide()
        return
    }

    if isFitting {
        OriginalWindowProperties.update(windowID: windowId)

        resizeAndMoveWindow(
            element: window,
            newPosition: snapRect.origin,
            newSize: snapRect.size,
            retries: 10
        )

        if let (screenNumber, workspaceNumber) = SpaceLayoutPreferences.getCurrentScreenAndSpace() {
            PlacedWindows.place(windowId: windowId,
                                screenNumber: screenNumber,
                                workspaceNumber: workspaceNumber,
                                layoutName: userLayouts.currentLayoutName,
                                sectionNumber: -1,
                                element: window)
        }

        justDidMouseUp = true
    }

    setIsFitting(false)
    toLeaveElement = nil
    toLeaveGridRect = nil
    gridLayoutWindow?.hide()
}

// MARK: - Window Cycling Functions

func cycleWindowsInZone(forward: Bool) {
    guard let focusedElement = getFocusedWindowAXUIElement(),
          let focusedWindowId = getWindowID(from: focusedElement) else {
        debugLog("No focused window found for cycling")
        return
    }
    
    // Check if the focused window is placed in a zone
    guard PlacedWindows.isPlaced(windowId: focusedWindowId) else {
        debugLog("Focused window is not placed in any zone")
        return
    }
    
    let windowsInZone = getWindowsInSameZone(as: focusedWindowId)
    
    // Need at least 2 windows to cycle
    guard windowsInZone.count > 1 else {
        debugLog("Not enough windows in zone to cycle (found \(windowsInZone.count))")
        return
    }
    
    // Find current window index
    guard let currentIndex = windowsInZone.firstIndex(where: { $0.windowId == focusedWindowId }) else {
        debugLog("Could not find current window in zone list")
        return
    }
    
    // Calculate next index
    let nextIndex: Int
    if forward {
        nextIndex = (currentIndex + 1) % windowsInZone.count
    } else {
        nextIndex = (currentIndex - 1 + windowsInZone.count) % windowsInZone.count
    }
    
    let targetWindow = windowsInZone[nextIndex]
    
    // Activate the target window
    activateWindow(element: targetWindow.element, windowId: targetWindow.windowId)
    
    debugLog("Cycled \(forward ? "forward" : "backward") to window \(targetWindow.windowId)")
}

func getWindowsInSameZone(as windowId: UInt32) -> [(windowId: UInt32, element: AXUIElement)] {
    guard let sectionNumber = PlacedWindows.windows[windowId],
          let layoutName = PlacedWindows.layouts[windowId],
          let screenNumber = PlacedWindows.screens[windowId],
          let workspaceNumber = PlacedWindows.workspaces[windowId] else {
        return []
    }
    
    var windowsInZone: [(windowId: UInt32, element: AXUIElement)] = []
    
    for (otherWindowId, otherSectionNumber) in PlacedWindows.windows {
        // Check if window is in the same zone (section, layout, screen, workspace)
        if otherSectionNumber == sectionNumber,
           PlacedWindows.layouts[otherWindowId] == layoutName,
           PlacedWindows.screens[otherWindowId] == screenNumber,
           PlacedWindows.workspaces[otherWindowId] == workspaceNumber,
           let element = PlacedWindows.elements[otherWindowId] {
            
            windowsInZone.append((windowId: otherWindowId, element: element))
        }
    }
    
    // Sort by window ID for consistent ordering
    windowsInZone.sort { $0.windowId < $1.windowId }
    
    return windowsInZone
}

func activateWindow(element: AXUIElement, windowId: UInt32) {
    // Get the application from the window element
    var pid: pid_t = 0
    let result = AXUIElementGetPid(element, &pid)
    
    guard result == .success else {
        debugLog("Failed to get PID for window \(windowId)")
        return
    }
    
    guard let app = NSRunningApplication(processIdentifier: pid) else {
        debugLog("Failed to get running application for PID \(pid)")
        return
    }
    
    // Activate the application and bring the window to front
    app.activate()
    
    // Use AX API to raise the specific window
    AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    
    debugLog("Activated window \(windowId) in application \(app.localizedName ?? "Unknown")")
}

func presentingShortcut(_ shortcut: String) -> String {
    let formattedShortcut = shortcut
        .replacingOccurrences(of: "Command", with: "⌘")
        .replacingOccurrences(of: "Control", with: "⌃")
        .replacingOccurrences(of: "Option", with: "⌥")
        .replacingOccurrences(of: "Shift", with: "⇧")
    
    return formattedShortcut
}
