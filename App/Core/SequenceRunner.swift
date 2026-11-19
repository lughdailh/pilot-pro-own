import Foundation

struct KeyStroke: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt64
    var label: String
    var isValid: Bool { keyCode <= 127 && modifiers & ~UInt64(0x1e0000) == 0 }
}

enum MacroStep: Codable, Equatable {
    case key(KeyStroke)
    case pause(Int)
    var isValid: Bool {
        switch self {
        case .key(let key): return key.isValid
        case .pause(let milliseconds): return (0...10_000).contains(milliseconds)
        }
    }
}

/// Main-queue sequence playback. It never blocks the UI or holds a key across a pause.
final class SequenceRunner {
    struct Job {
        var steps: [MacroStep]
        var validate: () -> Bool
        var emit: (KeyStroke) -> Void
        var finished: () -> Void
    }
    private var jobs: [Job] = []
    private var work: DispatchWorkItem?
    private var generation: UInt64 = 0
    private(set) var isBusy = false
    var onState: ((Bool) -> Void)?

    @discardableResult
    func enqueue(steps: [MacroStep], validate: @escaping () -> Bool, emit: @escaping (KeyStroke) -> Void, finished: @escaping () -> Void = {}) -> Bool {
        guard !steps.isEmpty, steps.count <= 100, steps.allSatisfy(\.isValid), jobs.count < 32 else { return false }
        jobs.append(Job(steps: steps, validate: validate, emit: emit, finished: finished))
        if !isBusy { startNext() }
        return true
    }
    func cancel() {
        generation &+= 1
        work?.cancel(); work = nil; jobs.removeAll()
        isBusy = false; onState?(false)
    }
    private func startNext() {
        guard !jobs.isEmpty else { isBusy = false; onState?(false); return }
        isBusy = true; onState?(true)
        let job = jobs.removeFirst()
        advance(job, index: 0, generation: generation)
    }
    private func advance(_ job: Job, index: Int, generation ticket: UInt64) {
        guard generation == ticket else { return }
        guard job.validate() else { cancel(); return }
        var cursor = index
        while cursor < job.steps.count {
            guard generation == ticket, job.validate() else { cancel(); return }
            switch job.steps[cursor] {
            case .key(let key): job.emit(key)
            case .pause(let milliseconds):
                let nextIndex = cursor + 1
                let item = DispatchWorkItem { [weak self] in self?.advance(job, index: nextIndex, generation: ticket) }
                work = item
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(milliseconds), execute: item)
                return
            }
            cursor += 1
        }
        guard generation == ticket else { return }
        job.finished()
        startNext()
    }
    deinit { work?.cancel() }
}
