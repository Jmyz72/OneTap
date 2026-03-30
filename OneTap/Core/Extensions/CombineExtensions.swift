//
//  CombineExtensions.swift
//  OneTap
//
//  Combine framework extensions for cleaner reactive code
//

import Foundation
import Combine

// MARK: - Publisher Extensions

extension Publisher where Failure == Never {
    /// Convenience method for subscribing with weak self capture on the main thread
    /// This helps prevent retain cycles and ensures UI updates happen on the main thread
    ///
    /// Usage:
    /// ```
    /// publisher.sinkOnMain(weak: self) { viewModel, value in
    ///     viewModel.someProperty = value
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - object: The object to weakly capture (typically self)
    ///   - receiveValue: Closure called with the weak reference and the published value
    /// - Returns: An AnyCancellable that can be stored in a cancellables set
    func sinkOnMain<T: AnyObject>(
        weak object: T,
        receiveValue: @escaping (T, Output) -> Void
    ) -> AnyCancellable {
        receive(on: DispatchQueue.main)
            .sink { [weak object] value in
                guard let object = object else { return }
                receiveValue(object, value)
            }
    }

    /// Convenience method for subscribing with weak self capture (without forcing main thread)
    /// Use this when you don't need main thread delivery or want to control threading yourself
    ///
    /// - Parameters:
    ///   - object: The object to weakly capture (typically self)
    ///   - receiveValue: Closure called with the weak reference and the published value
    /// - Returns: An AnyCancellable that can be stored in a cancellables set
    func sinkWeak<T: AnyObject>(
        _ object: T,
        receiveValue: @escaping (T, Output) -> Void
    ) -> AnyCancellable {
        sink { [weak object] value in
            guard let object = object else { return }
            receiveValue(object, value)
        }
    }
}

// MARK: - Publisher with Failure Extensions

extension Publisher {
    /// Convenience method for subscribing with weak self capture on main thread, handling both completion and value
    ///
    /// - Parameters:
    ///   - object: The object to weakly capture (typically self)
    ///   - receiveCompletion: Closure called when the publisher completes (with or without error)
    ///   - receiveValue: Closure called with each published value
    /// - Returns: An AnyCancellable that can be stored in a cancellables set
    func sinkOnMain<T: AnyObject>(
        weak object: T,
        receiveCompletion: @escaping (T, Subscribers.Completion<Failure>) -> Void,
        receiveValue: @escaping (T, Output) -> Void
    ) -> AnyCancellable {
        receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak object] completion in
                    guard let object = object else { return }
                    receiveCompletion(object, completion)
                },
                receiveValue: { [weak object] value in
                    guard let object = object else { return }
                    receiveValue(object, value)
                }
            )
    }
}

// MARK: - Debounce Convenience

extension Publisher {
    /// Convenience method for debouncing with the standard search delay
    /// Uses Constants.Debounce.search as the delay duration
    func debounceForSearch() -> Publishers.Debounce<Self, DispatchQueue> {
        debounce(for: .seconds(Constants.Debounce.search), scheduler: DispatchQueue.main)
    }

    /// Convenience method for debouncing context save notifications
    /// Uses Constants.Debounce.contextSave as the delay duration
    func debounceForContextSave() -> Publishers.Debounce<Self, DispatchQueue> {
        debounce(for: .seconds(Constants.Debounce.contextSave), scheduler: DispatchQueue.main)
    }
}
