import Foundation
import Receptacle

// MARK: - AIProvider

// The AIProvider protocol, AIProviderError enum, and CalendarEventDraft struct
// are defined in ReceptacleCore (Sources/ReceptacleCore/Protocols.swift and
// Sources/ReceptacleCore/CoreTypes.swift) and re-exported via `import Receptacle`.
//
// Concrete implementations live in:
//   Shared/AI/Cloud/ClaudeProvider.swift
//   Shared/AI/Cloud/OpenAIProvider.swift
//   Shared/AI/Local/WhisperProvider.swift
