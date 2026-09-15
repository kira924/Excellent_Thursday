# Excellent Thursday | الخميس الممتاز

An offline-friendly team buzzer app for the weekly *Excellent Thursday* game night. One phone hosts a local session over the same Wi-Fi network; every other phone joins as a player and gets a large, responsive buzzer.

The first release targets Android. The iOS project is included, but it still needs to be built and tested on macOS with Xcode.

## What it does

- Create a game with 2 to 8 custom-named teams.
- Let players join the host from the same local Wi-Fi network.
- Accept the first buzzer event received by the host and lock the other buzzers.
- Award **+1** for a correct answer and **−1** for an incorrect answer.
- Allow the same player or team to try again whenever the host reopens the buzzer.
- End the round when a team reaches **+5**; eliminate a team at **−5**. If only one team remains, it wins.
- Undo the last scored answer, save game scores locally, and reconnect players with the same identity after a network interruption or after the host returns from another app.
- Import host-only questions and answers from a complete AI reply, including JSON in a code block or explanatory text.

## Play a round

1. Install the same APK on the host's Android phone and every player's Android phone.
2. Connect every phone to the same Wi-Fi network. Internet access is not required.
3. On the host phone, choose **I am the host**, set the team count and names, then open the session.
4. Give players the six-digit session code and their team number.
5. Players choose **Join to play** and enter their name, code, and team. The app finds the host automatically on the local network.
6. The host reads a question, opens the buzzer, judges the first answer, and repeats until the round ends.

Moving the host app to the background closes an open buzzer and pauses its network listeners. Returning to the app rebinds both the WebSocket and discovery ports, preserving the session code, players, teams, questions, and scores. Failed rebinds retry automatically. Players keep the last known host address across failed attempts and try discovery as a fallback.

This recovery covers switching apps while the host process is alive. Force-stopping the host or the operating system killing its process still requires restoring the saved game and joining a new session.

If a player cannot join, verify the session code, turn off any VPN, and avoid guest Wi-Fi or router settings that isolate devices from one another.

For a device check, install 0.4.0 on every phone, score an answer, switch the host to another app for at least 30 seconds, then return. Leave players on their buzzer screens. Verify the same code, scores, and players remain, then open the buzzer and score another answer. Repeat once with the host screen locked.

## Questions

The app works in buzzer-only mode. To add questions, use **Add questions** on the host screen, copy the prepared prompt to an AI chat tool, review the answers, then paste the complete reply into the app. The importer accepts a plain JSON array, a `questions`/`items` wrapper, Markdown code fences, trailing commas, smart quotes, and Arabic question/answer keys. Questions and answers remain on the host device and are not sent to players.

```json
[
  {"question": "How many days are in a week?", "answer": "7"},
  {"question": "What is 9 multiplied by 8?", "answer": "72"}
]
```

See [examples/questions.json](examples/questions.json) for a ready-to-import Arabic example.

## Development

The project uses Flutter 3.41.7, Dart 3.11.5, Java 17, and Android SDK 36.

```powershell
flutter pub get
dart analyze lib test
flutter test --reporter expanded
flutter build apk --debug --target-platform android-arm64
```

The debug APK is for testing on Android 7+ ARM64 devices. Store distribution requires a separate release signing setup.

## Verification

The game rules, UDP host discovery, WebSocket host/client behavior, reconnection, score handling, question import, and mobile-sized Arabic UI are covered by automated tests. A real Wi-Fi test with two or more physical phones is still required before relying on it for a game night.

Version 0.4.0 adds regression tests for a host outage lasting across failed retries, unavailable discovery during reconnect, repeated suspend/resume, occupied ports during recovery, and a server that upgrades WebSocket but never completes player admission. All 14 tests pass, static analysis is clean, and the signed debug APK was built as version 0.4.0. Physical Android background/resume verification remains required; desktop tests do not reproduce every device power-management policy.

## Contributing

This repository is maintained by **Khaled Abdulrahman**. Changes to the default branch are made only by the repository owner's GitHub account. See [CONTRIBUTING.md](CONTRIBUTING.md).

Noto Sans Arabic is included under the [SIL Open Font License](assets/fonts/OFL.txt).
