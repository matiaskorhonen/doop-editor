//
//  TextViewController+LoadView.swift
//  CodeEditSourceEditor
//
//  Created by Khan Winter on 10/14/23.
//

import CodeEditTextView
import AppKit

extension TextViewController {
    override public func viewWillAppear() {
        super.viewWillAppear()
        // The calculation this causes cannot be done until the view knows it's final position
        updateTextInsets()
    }

    override public func viewDidAppear() {
        super.viewDidAppear()
        textCoordinators.forEach { $0.val?.controllerDidAppear(controller: self) }
    }

    override public func viewDidDisappear() {
        super.viewDidDisappear()
        textCoordinators.forEach { $0.val?.controllerDidDisappear(controller: self) }
    }

    override public func loadView() {
        super.loadView()

        scrollView = NSScrollView()
        scrollView.contentView = GutterBackgroundClipView()
        scrollView.documentView = textView

        gutterView = GutterView(
            configuration: configuration,
            controller: self,
            delegate: self
        )
        gutterView.updateWidthIfNeeded()
        scrollView.addFloatingSubview(gutterView, for: .horizontal)
        (scrollView.contentView as? GutterBackgroundClipView)?.gutterView = gutterView

        let findViewController = FindViewController(target: self, childView: scrollView)
        addChild(findViewController)
        self.findViewController = findViewController
        self.view.addSubview(findViewController.view)
        findViewController.view.viewDidMoveToSuperview()
        self.findViewController = findViewController

        if let _undoManager {
            textView.setUndoManager(_undoManager)
        }

        styleTextView()
        styleScrollView()

        setUpHighlighter()
        setUpTextFormation()

        if !cursorPositions.isEmpty {
            setCursorPositions(cursorPositions)
        }

        setUpConstraints()
        setUpOberservers()

        textView.updateFrameIfNeeded()

        if let localEventMonitor = self.localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }
        setUpKeyBindings(eventMonitor: &self.localEventMonitor)
        updateContentInsets()

        configuration.didSetOnController(controller: self, oldConfig: nil)
    }

    func setUpConstraints() {
        guard let findViewController else { return }

        NSLayoutConstraint.activate([
            findViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            findViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            findViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            findViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func setUpOnScrollChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] notification in
            guard notification.object is NSClipView else { return }
            self?.gutterView.needsDisplay = true
            NotificationCenter.default.post(name: Self.scrollPositionDidUpdateNotification, object: self)
        }
    }

    func setUpOnScrollViewFrameChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            self?.gutterView.needsDisplay = true
            self?.emphasisManager?.removeEmphases(for: EmphasisGroup.brackets)
            self?.updateTextInsets()
            NotificationCenter.default.post(name: Self.scrollPositionDidUpdateNotification, object: self)
        }
    }

    func setUpTextViewFrameChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.gutterView.frame.size.height = self.textView.frame.height + 10
            self.gutterView.frame.origin.y = self.textView.frame.origin.y - self.scrollView.contentInsets.top
            self.gutterView.needsDisplay = true
            self.scrollView.needsLayout = true
        }
    }

    func setUpSelectionChangedObserver() {
        NotificationCenter.default.addObserver(
            forName: TextSelectionManager.selectionChangedNotification,
            object: textView.selectionManager,
            queue: .main
        ) { [weak self] _ in
            self?.updateCursorPosition()
            self?.emphasizeSelectionPairs()
        }
    }

    func setUpAppearanceChangedObserver() {
        NSApp.publisher(for: \.effectiveAppearance)
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                guard let self = self else { return }

                if self.systemAppearance != newValue.name {
                    self.systemAppearance = newValue.name

                    // Reset content insets and gutter position when appearance changes
                    self.styleScrollView()
                    self.gutterView.frame.origin.y = self.textView.frame.origin.y - self.scrollView.contentInsets.top
                }
            }
            .store(in: &cancellables)
    }

    func setUpOberservers() {
        setUpOnScrollChangeObserver()
        setUpOnScrollViewFrameChangeObserver()
        setUpTextViewFrameChangeObserver()
        setUpSelectionChangedObserver()
        setUpAppearanceChangedObserver()
    }

    func setUpKeyBindings(eventMonitor: inout Any?) {
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown]
        ) { [weak self] event -> NSEvent? in
            guard let self = self else { return event }

            // Check if this window is key and if the text view is the first responder
            let isKeyWindow = self.view.window?.isKeyWindow ?? false
            let isFirstResponder = self.view.window?.firstResponder === self.textView

            // Only handle commands if this is the key window and text view is first responder
            guard isKeyWindow && isFirstResponder else { return event }
            return handleEvent(event: event)
        }
    }

    func handleEvent(event: NSEvent) -> NSEvent? {
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let tabKey: UInt16 = 0x30

        if event.keyCode == tabKey {
            return self.handleTab(event: event, modifierFlags: modifierFlags.rawValue)
        } else {
            return self.handleCommand(event: event, modifierFlags: modifierFlags)
        }
    }

    func handleCommand(event: NSEvent, modifierFlags: NSEvent.ModifierFlags) -> NSEvent? {
        let commandKey = NSEvent.ModifierFlags.command

        switch (modifierFlags, event.charactersIgnoringModifiers) {
        case (commandKey, "/"):
            handleCommandSlash()
            return nil
        case (commandKey, "["):
            handleIndent(inwards: true)
            return nil
        case (commandKey, "]"):
            handleIndent()
            return nil
        case (commandKey, "f"):
            _ = self.textView.resignFirstResponder()
            self.findViewController?.showFindPanel()
            return nil
        case (.init(rawValue: 0), "\u{1b}"): // Escape key
            if findViewController?.viewModel.isShowingFindPanel ?? false {
                self.findViewController?.hideFindPanel()
                return nil
            }
            return event
        case (_, _):
            return event
        }
    }

    /// Handles the tab key event.
    /// If the Shift key is pressed, it handles unindenting. If no modifier key is pressed, it checks if multiple lines
    /// are highlighted and handles indenting accordingly.
    ///
    /// - Returns: The original event if it should be passed on, or `nil` to indicate handling within the method.
    func handleTab(event: NSEvent, modifierFlags: UInt) -> NSEvent? {
        let shiftKey = NSEvent.ModifierFlags.shift.rawValue

        if modifierFlags == shiftKey {
            handleIndent(inwards: true)
        } else {
            // Only allow tab to work if multiple lines are selected
            guard multipleLinesHighlighted() else { return event }
            handleIndent()
        }
        return nil
    }
}
