# MVP Demo Checklist

## Demo Scope

This MVP demonstrates one card-driven encounter node:

- Encounter: `病村`
- Structure: 6 turns, then final event `疫病爆发`
- Per turn: draw cards, play cards with action points, end turn, trigger random event
- Player resources: action points, faith, followers, will, materials, exposure, sanity
- Encounter progress: cure progress, source clues, anchor progress, public trust, witness, infection, suspicion, route tendencies
- Final outcomes: cleanse plague, prayer circle, death authority, hidden escape, plague failure

## Godot Setup

1. Open the project in Godot 4.3+.
2. Create a new scene with root node `Control`.
3. Attach script:
   `res://game/ui/card_demo/card_demo_view.gd`
4. Save the scene, suggested path:
   `res://scenes/test/card_demo.tscn`
5. Run this scene directly.

The view script creates a temporary UI and a `CardRunController` automatically. No manual child nodes are required for the first demo.

## Optional Manual UI Integration

If building a custom UI, add a `CardRunController` node and call:

- `start_demo("sick_village")`
- `play_card(hand_index)`
- `end_turn()`
- `get_snapshot()`

Listen to:

- `state_changed(snapshot)`
- `log_added(message)`
- `encounter_finished(result)`

## Files

- Card data:
  `res://data/demo/card_demo/cards.json`
- Encounter data:
  `res://data/demo/card_demo/encounters.json`
- Core controller:
  `res://game/application/card_demo/card_run_controller.gd`
- Temporary demo UI:
  `res://game/ui/card_demo/card_demo_view.gd`

## Next Iteration Candidates

- Add card reward choice after the encounter.
- Add a node map with multiple encounter choices.
- Add route-specific decks for life, secret, and death.
- Add richer final-event choice UI instead of automatic first matching outcome.
- Connect encounter results to existing map tile states.
