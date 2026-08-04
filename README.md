# pH Analyzer (Edge-Computing Mobile App)

An offline-first Flutter application for precise, on-device pH prediction (0.00–14.00) from test strip images using **CIELAB color space transformation** and **natural cubic spline interpolation**.

---

## Features

- **100% Offline Edge Computing**: Performs color extraction, CIELAB delta calculations, and cubic spline interpolation locally without server calls.
- **Robust ROI Extraction**: Drag-and-drop region selection for **Dye Pad (Red)** and **Reference Background (Blue)** with automatic outlier removal (trimming 15% extreme highlights/shadows).
- **Live Camera & Gallery Support**: Supports real-time camera overlay box selection and gallery image picking with automatic EXIF orientation normalization.
- **Local History & Export**: Save test results locally with notes, thumbnails, and RGB values, and export/share PDF/image analysis reports.

---

## Prebuilt Calibration Reference Colors

The app uses prebuilt calibration anchor points located in [`assets/calibration.json`](assets/calibration.json). Each anchor maps a known pH value to its expected RGB color for the dye pad (`dye_rgb`) and reference background paper (`bg_rgb`).

### Current Prebuilt Standard Values

| Sample            | Median RGB          | Hex       | Approximate Appearance |
| ----------------- | ------------------- | --------- | ---------------------- |
| **NH₃**           | **(106, 100, 62)**  | `#6A643E` | Olive green            |
| **KOH**           | **(56, 49, 27)**    | `#38311B` | Dark olive brown       |
| **Soap solution** | **(87, 80, 56)**    | `#575038` | Olive brown            |
| **Water**         | **(96, 87, 68)**    | `#605744` | Beige-brown            |
| **Lemon**         | **(121, 91, 83)**   | `#795B53` | Salmon brown           |
| **Acetic acid**   | **(155, 136, 131)** | `#9B8883` | Pale pink              |
| **Dilute HCl**    | **(94, 47, 47)**    | `#5E2F2F` | Deep red               |
| **HCl**           | **(86, 50, 44)**    | `#56322C` | Dark brick red         |

---

## How to Change & Customize Calibration Values

You can customize the calibration values to match your specific pH test strip brand (e.g., Hydrion, Macherey-Nagel, MQuant, or custom indicator dyes).

### Step 1: Open the Calibration File
Navigate to the calibration file at:
```path
assets/calibration.json
```

### Step 2: Edit or Add Anchors
The JSON file contains an array of `anchors`. Each anchor requires three fields:

```json
{
  "anchors": [
    {
      "ph": 7.0,
      "dye_rgb": [60, 175, 80],
      "bg_rgb": [250, 250, 245]
    }
  ]
}
```

- **`ph`**: The known reference pH value (number between `0.0` and `14.0`).
- **`dye_rgb`**: Array of 3 integers `[Red, Green, Blue]` (values `0`–`255`) representing the dye pad color for that pH under standard lighting.
- **`bg_rgb`**: Array of 3 integers `[Red, Green, Blue]` (values `0`–`255`) representing the white reference background paper under the same lighting.

> [!NOTE]
> - Ensure you provide **at least 2 anchor points** across the target pH range so the natural cubic spline can interpolate intermediate values smoothly.
> - Anchors do **not** need to be manually pre-sorted in the JSON; the app automatically sorts anchors by pH upon loading.

### Step 3: Re-build or Hot Restart the App
After modifying `assets/calibration.json`:
1. Save the file.
2. If running Flutter, perform a **Hot Restart** (`Shift + R` in terminal, or restart via IDE) so Flutter reloads the updated asset bundle.

---

## How Calibration Analysis Works Under the Hood

1. **Color Conversion**: `dye_rgb` and `bg_rgb` are converted from sRGB to **CIE 1976 $L^*a^*b^*$** color space (which aligns with human vision color perception).
2. **Delta Calculation**: Color difference values $\Delta L^*$, $\Delta a^*$, $\Delta b^*$ are computed between the dye pad and the reference paper.
3. **Cubic Spline Interpolation**: Independent natural cubic splines ($\text{Spline}_L$, $\text{Spline}_A$, $\text{Spline}_B$) are fit over the anchor points.
4. **pH Prediction**: For any sample image, the app samples 141 candidate pH values ($0.00$ to $14.00$ with $0.1$ step size) on the spline curves and selects the pH that minimizes Euclidean distance in CIELAB space.

---

## Running the Application & Tests

### Run Unit Tests
```bash
flutter test
```

### Run Application
```bash
flutter run
```
