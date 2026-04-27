# Avocado Ripeness Detector

A deep learning-based avocado ripeness detection system that classifies avocado images into three categories: **unripe**, **ready**, and **overripe**. The model was trained and evaluated in **Edge Impulse**, then deployed into a **Flutter mobile application** for on-device image classification.

The final app allows users to capture an avocado image using the camera or select one from the gallery. The prediction result is displayed through an interactive flip-card interface with the predicted ripeness class, confidence score, and a short explanation.

---

## Project Links

- **GitHub repository:** https://github.com/Tongtong828/Avocado_ripe_camera
- **Edge Impulse project:** https://studio.edgeimpulse.com/public/968734/live 
---

## Project Overview

This project explores whether a lightweight deep learning model can classify avocado ripeness accurately enough for practical use on edge/mobile devices.

The workflow includes:

1. Collecting and preparing avocado image data
2. Reorganising the public dataset into three ripeness classes
3. Training and comparing different image classification models in Edge Impulse
4. Exporting the selected model as a TensorFlow Lite model
5. Integrating the model into a Flutter mobile app
6. Testing the app using camera capture and gallery image selection

---

## Ripeness Classes

| Class | Meaning |
|---|---|
| `unripe` | The avocado is not ready to eat yet |
| `ready` | The avocado is suitable for eating |
| `overripe` | The avocado is too ripe or should be used quickly |

---

## Data

Two main data sources were used in this project.

### Public Dataset

The main training dataset was the **'Hass' Avocado Ripening Photographic Dataset**. The original dataset contains multiple ripening stages, so it was reorganised into three final classes:

- `unripe`
- `ready`
- `overripe`

Several grouping strategies were compared in Edge Impulse. The final selected grouping strategy was:

```text
1 / 3 / 5
```

This split was selected because it produced the clearest visual separation between classes and reduced ambiguity in the middle ripeness stage. This was especially important because the `ready` class was consistently the most difficult class to classify.

### Self-Collected Dataset

A small self-collected dataset was also created to test model performance under more realistic conditions.

To reduce background and environmental interference, the images were captured using:

- A white background
- Consistent lighting conditions
- Similar framing and distance

This dataset was mainly used as an additional real-world validation set.

---

## Model Development

Several model types were tested in Edge Impulse, including:

- MobileNetV1 transfer learning
- MobileNetV2 transfer learning
- Default Regular CNN
- Custom CNN variants

The final selected model was:

```text
AvocadoRipe2_30
```

This custom CNN was selected because it provided a good balance between accuracy, explainability, and mobile deployment efficiency.

### Final Model Architecture

```text
Input: 96 x 96 RGB image

2D Conv / Pool Layer
- 16 filters
- kernel size 3

Dropout
- rate 0.10

2D Conv / Pool Layer
- 32 filters
- kernel size 3

Dropout
- rate 0.15

2D Conv / Pool Layer
- 64 filters
- kernel size 3

Dropout
- rate 0.20

Flatten Layer

Dense Layer
- 32 neurons

Dropout
- rate 0.50

Output Layer
- 3 classes: overripe / ready / unripe
```

The model was designed to gradually learn low-level and higher-level avocado skin features while reducing overfitting.

---

## Experiment Summary

A total of **14 model experiments** were carried out in Edge Impulse.

The parameters tested included:

- Model type
- Number of training epochs
- Dense layer size
- Dropout rate
- Learning rate

Key findings:

- MobileNetV2 performed better than MobileNetV1.
- Regular CNN performed well, but it was a default model.
- The first custom AvocadoRipe model with a 64-neuron dense layer did not generalise as well.
- Reducing the dense layer to 32 neurons improved the custom model.
- A dense layer with 16 neurons caused underfitting.
- A dense layer with 48 neurons did not improve performance.
- A dropout rate of 0.5 worked best for the final custom CNN.
- A learning rate of 0.0005 was more stable than 0.001 or 0.0001.

The final selected model, **AvocadoRipe2_30**, achieved:

```text
Validation accuracy: 93.9%
Loss: 0.17
Float32 test accuracy: 81.3%
Estimated latency: 259 ms
```

---

## Mobile Application

The final model was deployed into a Flutter mobile app.

### App Features

- Live camera preview
- Scan-style animation
- Capture image using camera
- Choose image from gallery
- On-device TensorFlow Lite inference
- Flip-card result interaction
- Ripeness class display
- Confidence score display
- Short explanation for the predicted class

---

## Deployment Process

The trained model was exported from Edge Impulse as an **Android library package**.

The downloaded deployment package was a `.zip` file. After extraction, the key model file was found inside the following folder:

```text
tflite-model/
```

The `.tflite` model file was copied into the Flutter project assets folder and registered in `pubspec.yaml`.

Example asset structure:

```text
assets/
  avocados/
    unripe.png
    ready.png
    overripe.png
  model/
    avocado_model.tflite
```

The model is loaded in the app using a TensorFlow Lite interpreter. Before inference, input images are resized to:

```text
96 x 96 pixels
```

and converted into the required input format.

---

## Flutter Project Setup

### Requirements

- Flutter SDK
- Android Studio or VS Code
- Android device or emulator
- Camera permission enabled
- Gallery access permission enabled

### Install Dependencies

```bash
flutter pub get
```

### Run the App

```bash
flutter run
```

### Build APK

To build a release APK:

```bash
flutter clean
flutter pub get
flutter build apk --release
```

The APK will be generated at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## Main Dependencies

The Flutter app uses:

```yaml
camera
image_picker
tflite_flutter
image
```

These packages support camera capture, gallery image selection, image preprocessing, and TensorFlow Lite model inference.

---

## Project Structure

```text
avocado_detector_app/
  android/
  assets/
    avocados/
      unripe.png
      ready.png
      overripe.png
    model/
      avocado_model.tflite
  lib/
    main.dart
    home_page.dart
    result_card.dart
    model_service.dart
  pubspec.yaml
  README.md
```

---

## Limitations

The system works as a functional prototype, but it does not perform perfectly in all real-world conditions.

The main limitation is that the model is sensitive to image capture conditions, especially lighting. The `ready` class is the most difficult to classify because it lies between the clearer visual states of `unripe` and `overripe`.

Testing with self-collected images showed that inconsistent lighting could reduce performance, especially for ready avocados. After re-photographing ready samples under more consistent lighting, the results improved.

---

## Future Improvements

Future work could include:

- Collecting a larger self-collected dataset
- Adding more images of the `ready` class
- Testing under different lighting conditions
- Adding data augmentation for brightness, contrast, background, and camera angle
- Improving robustness for real-world use
- Comparing more lightweight mobile-friendly model architectures

---

## References

1. Xavier, P., Rodrigues, P.M. and Silva, C.L.M. (2024). *'Hass' Avocado Ripening Photographic Dataset*. Amsterdam: Mendeley Data. https://doi.org/10.17632/3xd9n945v8.1

2. Xavier, P., Rodrigues, P.M. and Silva, C.L.M. (2024). *Shelf-Life Management and Ripening Assessment of 'Hass' Avocado (Persea americana) Using Deep Learning Approaches*. Foods, 13(8), Article 1150. https://doi.org/10.3390/foods13081150

3. Edge Impulse. (n.d.). *Data acquisition*. Edge Impulse Documentation. https://docs.edgeimpulse.com/studio/projects/data-acquisition

4. Edge Impulse. (n.d.). *Transfer learning for images*. Edge Impulse Documentation. https://docs.edgeimpulse.com/studio/projects/learning-blocks/blocks/transfer-learning-images

5. Flutter. (n.d.). *Camera plugin*. Flutter Packages. https://pub.dev/packages/camera

6. Flutter. (n.d.). *Image picker plugin*. Flutter Packages. https://pub.dev/packages/image_picker

7. tflite_flutter. (n.d.). *TensorFlow Lite Flutter*. Pub.dev Documentation. https://pub.dev/packages/tflite_flutter

---

## Author

Tong

---

## Declaration

This project was developed as part of a deep learning / sensor network coursework project. Public datasets and external tools are acknowledged where used. The mobile application, dataset processing, model experiments, and deployment workflow were developed for this project.
