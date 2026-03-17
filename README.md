# MacWidget

Native macOS CPU monitor with a real WidgetKit desktop widget and a small host app for local testing and timeline reloads.

## What it shows

- Live CPU usage with a circular gauge
- Thermal pressure state from macOS
- Busy logical CPU count
- Logical and physical CPU counts
- System and task thread counts

## Why thermal pressure instead of CPU temperature

On current macOS builds, CPU die temperature is not exposed through a stable public API. This app uses the real thermal pressure signal that macOS does expose, instead of inventing a fake temperature.

## Project layout

- `App/`: host macOS app
- `WidgetExtension/`: WidgetKit extension
- `Shared/`: shared metrics sampling and UI
- `scripts/build_widgetkit_app.sh`: generate, build, sign, and launch the WidgetKit app
- `scripts/run_app.sh`: open the built host app
- `scripts/stop_app.sh`: stop the host app process

## Build and run the WidgetKit app

```bash
./scripts/build_widgetkit_app.sh
```

After building, add `CPU Usage` from macOS `Edit Widgets`.

## Open and stop the host app

```bash
./scripts/run_app.sh
./scripts/stop_app.sh
```
