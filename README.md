# MindChat iOS

A native SwiftUI iOS application that combines AI-powered conversations with an intelligent personal knowledge base. MindChat automatically extracts, organizes, and surfaces your knowledge from natural conversations.

<p align="center">
  <img src="MindChat-Logo.svg" alt="MindChat Logo" width="120" />
</p>

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Requirements](#requirements)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Authentication](#authentication)
- [Chat & Streaming](#chat--streaming)
- [Knowledge Base](#knowledge-base)
- [AI Models & Plans](#ai-models--plans)
- [Theme System](#theme-system)
- [Deep Linking](#deep-linking)
- [Caching & Performance](#caching--performance)
- [Security](#security)
- [API Reference](#api-reference)
- [Dependencies](#dependencies)
- [License](#license)

## Features

### Conversational AI
- **Real-time streaming** responses via Server-Sent Events (SSE)
- **Multi-provider support** — OpenAI, Anthropic (Claude), Google (Gemini), xAI (Grok)
- **40+ AI models** with plan-based access tiers
- **Live indicators** — thinking timer, web search animation, memory extraction progress
- **Message actions** — copy, edit, regenerate, retry on error

### Intelligent Knowledge Base
- **Automatic extraction** — topics and facts are extracted from conversations
- **Hierarchical topics** — tree structure with parent/child relationships
- **Fact types** — facts, preferences, goals, and experiences with importance levels
- **Full-text search** with type and importance filters
- **Topic merging** — combine duplicate or related topics

### Authentication & Security
- Email/password authentication with token refresh
- Google Sign-In (OAuth)
- Password recovery and email verification flows
- Secure JWT storage in iOS Keychain

### Rich Chat Experience
- Markdown rendering in assistant responses
- File and image uploads (plan-gated)
- Voice input with transcription (plan-gated)
- Conversation history with search and swipe actions
- Character counter and input validation

### Personalization
- Light, dark, and system theme modes
- High-contrast accessibility mode
- 8 accent color options
- 3 font size scales (small, medium, large)
- 5 persona modes (concise, balanced, detailed, casual, professional)
- 14 supported languages
- 4 chat memory modes

### Subscription & Plans
- Free, Trial, Pro, and Premium tiers
- Stripe-powered checkout and billing portal
- Usage tracking with daily message quotas
- Feature gating based on plan level

## Architecture

MindChat follows the **MVVM** (Model-View-ViewModel) pattern with **Swift Concurrency** (async/await) throughout.

```
┌─────────────────────────────────────────────┐
│                    Views                     │
│  (SwiftUI views, purely declarative UI)      │
├─────────────────────────────────────────────┤
│                 ViewModels                   │
│  (@MainActor, @Published state, async ops)   │
├─────────────────────────────────────────────┤
│                  Services                    │
│  (API calls, SSE parsing, Keychain, cache)   │
├─────────────────────────────────────────────┤
│                   Models                     │
│  (Codable structs, enums, Sendable types)    │
└─────────────────────────────────────────────┘
```

**Key architectural decisions:**

- **Swift 6 concurrency** — `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` with `Sendable` types throughout
- **Event-driven updates** — `EventBus` (pub/sub) for cross-feature communication without tight coupling
- **Cache-first loading** — `CacheStore` with TTL-based expiration returns cached data instantly, then refreshes in background
- **Token management** — automatic silent refresh on 401 with single retry

## Project Structure

```
Mind Chat/
├── Mind_ChatApp.swift                 # App entry point & environment setup
├── ContentView.swift                  # Auth gate & MainTabView with sidebar
│
├── App/
│   └── AppState.swift                 # Global state, deep link handling, auth status
│
├── Models/
│   ├── Types.swift                    # Core data types & enums
│   ├── PlanLimits.swift               # Subscription tier definitions & feature gates
│   └── APIResponses.swift             # Codable API response DTOs
│
├── Services/
│   ├── APIClient.swift                # Base HTTP client with auth & token refresh
│   ├── AuthService.swift              # Login, register, OAuth, password flows
│   ├── ChatService.swift              # Chat messaging & conversation CRUD
│   ├── TopicService.swift             # Knowledge base tree, search, facts
│   ├── SettingsService.swift          # User preferences & usage stats
│   ├── UploadService.swift            # File/image upload & audio transcription
│   ├── StripeService.swift            # Checkout & customer portal
│   ├── AccountService.swift           # Account management & data export
│   ├── KeychainManager.swift          # Secure token storage
│   └── SSEParser.swift                # Server-Sent Events stream parser
│
├── ViewModels/
│   ├── ChatViewModel.swift            # Chat state, streaming, message handling
│   ├── ConversationsViewModel.swift   # Conversation history management
│   ├── TopicsViewModel.swift          # Knowledge base hierarchy & stats
│   ├── TopicDetailViewModel.swift     # Individual topic with facts
│   ├── AuthViewModel.swift            # Login/signup/password reset forms
│   ├── SettingsViewModel.swift        # User preferences & model selection
│   ├── SearchViewModel.swift          # Knowledge search state
│   └── PlanViewModel.swift            # Subscription & trial management
│
├── Views/
│   ├── Auth/                          # Login, signup, password reset, verification
│   ├── Chat/                          # Chat UI, messages, input, indicators
│   ├── Topics/                        # Knowledge dashboard, topic detail, search
│   ├── Settings/                      # Settings, subscriptions, account
│   ├── Conversations/                 # Conversation history & list
│   ├── Components/                    # Reusable UI (toast, skeleton, scroll button)
│   └── Onboarding/                    # First-launch onboarding flow
│
├── Theme/
│   ├── ThemeManager.swift             # Light/dark/system + high-contrast
│   ├── Colors.swift                   # Full color palettes for all modes
│   └── Typography.swift               # Font scaling system
│
├── Utilities/
│   ├── EventBus.swift                 # Pub/sub event system
│   ├── CacheStore.swift               # In-memory TTL cache
│   ├── Validators.swift               # Email, password, name validation
│   ├── DateFormatting.swift           # Date display & ISO 8601 codecs
│   └── Haptics.swift                  # Haptic feedback helpers
│
└── Assets.xcassets/                   # App icon, accent color, color assets
```

## Requirements

| Requirement | Version |
|---|---|
| iOS | 18.0+ |
| Xcode | 16.0+ |
| Swift | 5.0+ (Swift 6 concurrency enabled) |

## Getting Started

1. **Clone the repository**

   ```bash
   git clone https://github.com/hadibavili/mindchat-ios.git
   cd mindchat-ios
   ```

2. **Open in Xcode**

   ```bash
   open "Mind Chat.xcodeproj"
   ```

3. **Configure signing**

   - Select the `Mind Chat` target
   - Under **Signing & Capabilities**, set your development team
   - Xcode will automatically manage provisioning profiles

4. **Build and run**

   - Select a simulator or connected device
   - Press `Cmd + R` to build and run

## Configuration

### API Base URL

The backend API base URL is configured in `Services/APIClient.swift`:

```swift
private let baseURL = "https://app.mindchat.fenqor.nl"
```

### Bundle Identifier

```
com.fenqor.mindchat
```

### Info.plist Permissions

The app requests the following permissions:

| Permission | Usage |
|---|---|
| `NSCameraUsageDescription` | Capture photos for messages |
| `NSMicrophoneUsageDescription` | Record voice messages for transcription |
| `NSPhotoLibraryUsageDescription` | Attach images to messages |

## Authentication

MindChat uses JWT-based authentication with automatic token refresh.

### Flow

```
Login/Register → Access Token + Refresh Token → Keychain Storage
         ↓
   API Request (Bearer token)
         ↓
   401 Unauthorized? → Silent refresh → Retry request
         ↓
   Refresh failed? → Sign out → Login screen
```

### Supported Methods

- **Email/Password** — standard registration and login with validation
- **Google Sign-In** — OAuth with Google ID token exchange
- **Password Recovery** — email-based forgot/reset password flow
- **Email Verification** — banner prompt with resend capability

## Chat & Streaming

Chat uses **Server-Sent Events (SSE)** for real-time token streaming:

```
Client → POST /api/chat (message + history + settings)
Server → SSE stream:
  ├── conversationId    (conversation identifier)
  ├── conversationTitle (auto-generated title)
  ├── token             (streamed response tokens)
  ├── searching         (web search started)
  ├── searchComplete    (search results with sources)
  ├── extracting        (memory extraction started)
  ├── topicsExtracted   (extracted topic pills)
  ├── error             (error message)
  └── done              (stream complete)
```

### Memory Modes

| Mode | Description |
|---|---|
| Always Persist | Automatic memory extraction from every conversation |
| Persist & Clearable | Extract memories, user can clear on demand |
| Fresh | No memory — clean conversation every time |
| Extract Only | Extract topics without persisting to knowledge base |

## Knowledge Base

MindChat automatically extracts structured knowledge from conversations into a hierarchical topic system.

### Structure

```
Topics (tree)
├── Technology
│   ├── iOS Development
│   │   ├── Fact: "Prefers SwiftUI over UIKit"
│   │   └── Preference: "Uses MVVM architecture"
│   └── Backend
│       └── Goal: "Learn Rust for systems programming"
├── Health & Fitness
│   └── Experience: "Completed first marathon in 2025"
└── ...
```

### Fact Types

| Type | Color | Description |
|---|---|---|
| Fact | Blue | General knowledge and information |
| Preference | Purple | Personal preferences and opinions |
| Goal | Green | Aspirations and objectives |
| Experience | Orange | Past events and experiences |

### Importance Levels

- **High** — critical information, always surfaced
- **Medium** — important context
- **Low** — supplementary details
- **None** — minor or trivial

## AI Models & Plans

### Supported Providers & Models

| Provider | Free | Pro | Premium |
|---|---|---|---|
| **OpenAI** | GPT-5 Nano | GPT-5 Mini, GPT-5 | GPT-5.1, O3, O4 Mini |
| **Anthropic** | Claude Haiku | Claude Sonnet | Claude Opus |
| **Google** | Gemini Flash | Gemini Pro | Gemini Pro |
| **xAI** | Grok Mini | Grok 3 | Grok 3 |

### Plan Comparison

| Feature | Free | Trial | Pro | Premium |
|---|---|---|---|---|
| Daily messages | 25 | 300 | 300 | 1,000 |
| Max facts | 50 | 1,000 | 1,000 | 5,000 |
| Voice input | — | Yes | Yes | Yes |
| Image uploads | — | Yes | Yes | Yes |
| Web search | — | Yes | Yes | Yes |
| Custom API keys | — | Yes | Yes | Yes |
| Priority models | — | — | — | Yes |

## Theme System

### Color Modes

- **Light** — clean white backgrounds with warm gray text
- **Dark** — deep gray/black backgrounds with light text
- **System** — follows iOS appearance setting
- **High Contrast** — enhanced contrast for accessibility (both light and dark variants)

### Accent Colors

8 customizable accent colors: Black, Green, Blue, Purple, Pink, Orange, Cyan, Red

### Typography Scale

| Scale | Multiplier | Body Size |
|---|---|---|
| Small | 0.875x | ~15pt |
| Medium | 1.0x | 17pt |
| Large | 1.15x | ~20pt |

## Deep Linking

MindChat supports the `mindchat://` URL scheme:

| URL | Action |
|---|---|
| `mindchat://reset-password?token=X` | Open password reset flow |
| `mindchat://verify-email?token=X` | Verify email address |
| `mindchat://chat/{conversationId}` | Navigate to specific conversation |
| `mindchat://topics/{path}` | Navigate to topic by path |

## Caching & Performance

### Cache Strategy

MindChat uses a **cache-first** approach — cached data is returned immediately to avoid loading spinners, with background refresh when stale.

| Data | TTL | Invalidation Trigger |
|---|---|---|
| Conversations list | 5 min | `conversationCreated` event |
| Topic tree | 10 min | `topicsUpdated` event |
| Topic stats | 10 min | `topicsUpdated` event |
| Topic detail | 5 min | `factsUpdated` event |

### Event Bus

Cross-feature communication via a global pub/sub system (`EventBus`):

- `conversationCreated` — triggers conversation list refresh
- `topicsUpdated` — triggers knowledge base refresh
- `factsUpdated` — triggers topic detail + tree refresh
- `modelChanged` — syncs model selection across views
- `userSignedOut` — clears all state and cache

## Security

| Layer | Implementation |
|---|---|
| Token storage | iOS Keychain (`kSecAttrAccessibleAfterFirstUnlock`) |
| Authentication | JWT Bearer tokens with automatic refresh |
| Password | Never persisted; validated client-side before submission |
| Token lifecycle | Access + refresh tokens; cleared on sign-out |
| Input validation | Regex-based email, strength-checked passwords, name length |

## API Reference

### Base URL

```
https://app.mindchat.fenqor.nl
```

### Endpoints

<details>
<summary><strong>Authentication</strong></summary>

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/auth/mobile/login` | Email/password or Google OAuth login |
| `POST` | `/api/auth/mobile/register` | New user registration |
| `POST` | `/api/auth/mobile/refresh` | Refresh access token |
| `POST` | `/api/auth/forgot-password` | Send password reset email |
| `POST` | `/api/auth/reset-password` | Reset password with token |
| `POST` | `/api/auth/resend-verification` | Resend email verification |

</details>

<details>
<summary><strong>Chat & Conversations</strong></summary>

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/chat` | Send message (SSE streaming response) |
| `GET` | `/api/messages?conversationId=X` | Load conversation messages |
| `DELETE` | `/api/messages?conversationId=X` | Clear conversation messages |
| `GET` | `/api/conversations` | List all conversations |
| `POST` | `/api/conversations` | Create new conversation |
| `GET` | `/api/conversations/{id}` | Get conversation details |
| `PATCH` | `/api/conversations/{id}` | Rename conversation |
| `DELETE` | `/api/conversations/{id}` | Delete conversation |

</details>

<details>
<summary><strong>Knowledge Base</strong></summary>

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/topics` | Get full topic tree |
| `GET` | `/api/topics/{id}` | Get topic with facts and children |
| `GET` | `/api/topics/lookup?path=X` | Lookup topic by path |
| `GET` | `/api/topics/search?q=X&type=Y&importance=Z` | Search knowledge base |
| `GET` | `/api/topics/stats` | Get knowledge statistics |
| `POST` | `/api/topics/merge` | Merge topics |
| `PATCH` | `/api/facts/{id}` | Update a fact |
| `DELETE` | `/api/facts/{id}` | Delete a fact |

</details>

<details>
<summary><strong>Settings, Uploads & Billing</strong></summary>

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/settings` | Get user preferences |
| `PUT` | `/api/settings` | Update preferences |
| `GET` | `/api/usage` | Get usage stats and plan limits |
| `POST` | `/api/upload` | Upload file/image (multipart) |
| `POST` | `/api/transcribe` | Transcribe audio file |
| `POST` | `/api/stripe/checkout` | Get Stripe checkout URL |
| `POST` | `/api/stripe/portal` | Get Stripe customer portal URL |
| `POST` | `/api/trial` | Start free trial |

</details>

## Dependencies

### Current

No third-party SPM packages are currently linked. The app is built entirely with native frameworks:

- **SwiftUI** — declarative UI
- **Foundation** — networking, JSON, Keychain
- **Security** — Keychain Services

### Planned (requires manual addition via Xcode)

| Package | Repository | Purpose |
|---|---|---|
| MarkdownUI | [gonzalezreal/swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) | Rich markdown rendering (currently stubbed with `AttributedString`) |
| PostHog iOS | [PostHog/posthog-ios](https://github.com/PostHog/posthog-ios) | Analytics and event tracking |
| GoogleSignIn | [google/GoogleSignIn-iOS](https://github.com/google/GoogleSignIn-iOS) | Google OAuth sign-in |

## License

All rights reserved. This is proprietary software.
