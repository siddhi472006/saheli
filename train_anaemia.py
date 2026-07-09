"""
Saheli — Anaemia Detection Model
Dataset: Eyes-Defy-Anemia (Kaggle)

"""

import os
import numpy as np
import matplotlib.pyplot as plt
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.model_selection import train_test_split
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from PIL import Image
import pathlib

# ── Configuration ─────────────────────────────────────────────
IMG_SIZE         = 224
BATCH_SIZE       = 16
EPOCHS           = 40
FINE_TUNE_EPOCHS = 20
DATASET_DIR      = "dataset"
OUTPUT_PATH      = "assets/models/anaemia_model.tflite"

os.makedirs("assets/models", exist_ok=True)

# ── 1. Load Dataset ───────────────────────────────────────────
print("📂 Loading Eyes-Defy-Anemia dataset...")

def load_images(folder, label):
    images, labels = [], []
    supported = {'.jpg', '.jpeg', '.png', '.bmp'}
    for p in pathlib.Path(folder).rglob('*'):
        if p.suffix.lower() not in supported:
            continue
        try:
            img = Image.open(p).convert('RGB').resize((IMG_SIZE, IMG_SIZE))
            arr = np.array(img, dtype=np.float32) / 255.0
            images.append(arr)
            labels.append(label)
        except Exception as e:
            print(f"  Skipping {p.name}: {e}")
    print(f"  {folder}: {len(images)} images loaded (label={label})")
    return images, labels

# label 1 = anemic (pale), label 0 = healthy (pink)
anemic_imgs,  anemic_lbls  = load_images(
    os.path.join(DATASET_DIR, "anemic"),     1)
healthy_imgs, healthy_lbls = load_images(
    os.path.join(DATASET_DIR, "non_anemic"), 0)

X = np.array(anemic_imgs  + healthy_imgs,  dtype=np.float32)
y = np.array(anemic_lbls  + healthy_lbls,  dtype=np.float32)

print(f"\n  Total images : {len(X)}")
print(f"  Anemic       : {int(sum(y == 1))}")
print(f"  Healthy      : {int(sum(y == 0))}")

# ── 2. Train / Val / Test Split ───────────────────────────────
# 70% train, 15% validation, 15% test
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.15, random_state=42, stratify=y)

X_train, X_val, y_train, y_val = train_test_split(
    X_train, y_train, test_size=0.15, random_state=42, stratify=y_train)

print(f"\n  Train : {len(X_train)}")
print(f"  Val   : {len(X_val)}")
print(f"  Test  : {len(X_test)}")

# ── 3. Data Augmentation ──────────────────────────────────────
# Critical for small datasets — artificially expands training data
# by applying realistic transformations to existing images
data_augmentation = keras.Sequential([
    layers.RandomFlip("horizontal"),       # mirror image left-right
    layers.RandomFlip("vertical"),         # mirror image top-bottom
    layers.RandomRotation(0.15),           # rotate up to 15%
    layers.RandomZoom(0.15),               # zoom in/out up to 15%
    layers.RandomBrightness(0.25),         # vary brightness ±25%
    layers.RandomContrast(0.25),           # vary contrast ±25%
], name="data_augmentation")

# ── 4. Model Architecture ─────────────────────────────────────
# Transfer Learning with MobileNetV2
# Pre-trained on ImageNet (14M images, 1000 classes)
# We fine-tune it for our binary anaemia classification task
print("\n🏗  Building MobileNetV2 transfer learning model...")

base_model = keras.applications.MobileNetV2(
    input_shape=(IMG_SIZE, IMG_SIZE, 3),
    include_top=False,         # remove ImageNet classification head
    weights='imagenet'         # use pretrained weights
)
base_model.trainable = False   # freeze all layers for phase 1

inputs = keras.Input(shape=(IMG_SIZE, IMG_SIZE, 3))

# Augmentation only applied during training
x = data_augmentation(inputs)

# MobileNetV2 preprocessing: scales pixels to [-1, 1]
x = keras.applications.mobilenet_v2.preprocess_input(x * 255.0)

# Pass through frozen MobileNetV2 base
x = base_model(x, training=False)

# Classification head
x = layers.GlobalAveragePooling2D()(x)   # 7×7×1280 → 1280
x = layers.BatchNormalization()(x)
x = layers.Dense(128, activation='relu')(x)
x = layers.Dropout(0.4)(x)              # prevent overfitting
x = layers.Dense(64,  activation='relu')(x)
x = layers.Dropout(0.3)(x)

# Output: sigmoid → 0.0 (healthy) to 1.0 (anemic)
outputs = layers.Dense(
    1, activation='sigmoid', name='anaemia_output')(x)

model = keras.Model(inputs, outputs, name="SaheliAnaemiaDetector")
model.summary()

# ── 5. Phase 1: Train Classification Head Only ────────────────
print("\n🔥 Phase 1: Training classification head (base frozen)...")

model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=1e-3),
    loss='binary_crossentropy',
    metrics=[
        'accuracy',
        keras.metrics.AUC(name='auc'),
        keras.metrics.Precision(name='precision'),
        keras.metrics.Recall(name='recall'),
    ]
)

callbacks = [
    keras.callbacks.EarlyStopping(
        monitor='val_auc',
        patience=8,
        restore_best_weights=True,
        mode='max',
        verbose=1,
    ),
    keras.callbacks.ReduceLROnPlateau(
        monitor='val_loss',
        factor=0.5,
        patience=4,
        min_lr=1e-7,
        verbose=1,
    ),
    keras.callbacks.ModelCheckpoint(
        'best_model_phase1.keras',
        monitor='val_auc',
        save_best_only=True,
        mode='max',
    ),
]

history1 = model.fit(
    X_train, y_train,
    validation_data=(X_val, y_val),
    epochs=EPOCHS,
    batch_size=BATCH_SIZE,
    callbacks=callbacks,
    verbose=1,
)

# ── 6. Phase 2: Fine-tune Top MobileNetV2 Layers ─────────────
print("\n🔧 Phase 2: Fine-tuning top 30 MobileNetV2 layers...")

# Unfreeze top 30 layers for fine-tuning
base_model.trainable = True
for layer in base_model.layers[:-30]:
    layer.trainable = False

trainable_count = sum(
    1 for l in base_model.layers if l.trainable)
print(f"  Trainable layers in base: {trainable_count} / {len(base_model.layers)}")

# Much lower learning rate to avoid destroying pretrained weights
model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=1e-5),
    loss='binary_crossentropy',
    metrics=[
        'accuracy',
        keras.metrics.AUC(name='auc'),
        keras.metrics.Precision(name='precision'),
        keras.metrics.Recall(name='recall'),
    ]
)

callbacks_ft = [
    keras.callbacks.EarlyStopping(
        monitor='val_auc',
        patience=6,
        restore_best_weights=True,
        mode='max',
        verbose=1,
    ),
    keras.callbacks.ReduceLROnPlateau(
        monitor='val_loss',
        factor=0.5,
        patience=3,
        min_lr=1e-8,
        verbose=1,
    ),
    keras.callbacks.ModelCheckpoint(
        'best_model_phase2.keras',
        monitor='val_auc',
        save_best_only=True,
        mode='max',
    ),
]

history2 = model.fit(
    X_train, y_train,
    validation_data=(X_val, y_val),
    epochs=FINE_TUNE_EPOCHS,
    batch_size=BATCH_SIZE,
    callbacks=callbacks_ft,
    verbose=1,
)

# ── 7. Evaluate on Test Set ───────────────────────────────────
print("\n📊 Final evaluation on held-out test set:")
loss, acc, auc, precision, recall = model.evaluate(
    X_test, y_test, verbose=0)

print(f"  Loss      : {loss:.4f}")
print(f"  Accuracy  : {acc:.4f}  ({acc*100:.1f}%)")
print(f"  AUC       : {auc:.4f}")
print(f"  Precision : {precision:.4f}")
print(f"  Recall    : {recall:.4f}")
print(f"  F1 Score  : {2*precision*recall/(precision+recall):.4f}")

y_pred_prob = model.predict(X_test, verbose=0).flatten()
y_pred      = (y_pred_prob > 0.5).astype(int)

print("\nClassification Report:")
print(classification_report(
    y_test, y_pred,
    target_names=['Healthy (0)', 'Anaemic (1)']))

cm = confusion_matrix(y_test, y_pred)
print(f"Confusion Matrix:")
print(f"  TN={cm[0][0]}  FP={cm[0][1]}")
print(f"  FN={cm[1][0]}  TP={cm[1][1]}")

sensitivity = cm[1][1] / (cm[1][1] + cm[1][0])
specificity = cm[0][0] / (cm[0][0] + cm[0][1])
print(f"\n  Sensitivity (Recall for Anaemic) : {sensitivity:.4f}")
print(f"  Specificity (Recall for Healthy) : {specificity:.4f}")

# ── 8. Training Curves ────────────────────────────────────────
all_acc     = history1.history['accuracy']     + history2.history['accuracy']
all_val_acc = history1.history['val_accuracy'] + history2.history['val_accuracy']
all_loss    = history1.history['loss']         + history2.history['loss']
all_val_loss= history1.history['val_loss']     + history2.history['val_loss']
all_auc     = history1.history['auc']          + history2.history['auc']
all_val_auc = history1.history['val_auc']      + history2.history['val_auc']

phase1_end = len(history1.history['accuracy'])

fig, axes = plt.subplots(1, 3, figsize=(15, 5))
fig.suptitle('Saheli — Anaemia Model Training', fontsize=14)

axes[0].plot(all_acc,     label='Train')
axes[0].plot(all_val_acc, label='Validation')
axes[0].axvline(x=phase1_end, color='gray', linestyle='--', label='Fine-tune')
axes[0].set_title('Accuracy')
axes[0].set_xlabel('Epoch')
axes[0].legend()

axes[1].plot(all_loss,     label='Train')
axes[1].plot(all_val_loss, label='Validation')
axes[1].axvline(x=phase1_end, color='gray', linestyle='--', label='Fine-tune')
axes[1].set_title('Loss')
axes[1].set_xlabel('Epoch')
axes[1].legend()

axes[2].plot(all_auc,     label='Train')
axes[2].plot(all_val_auc, label='Validation')
axes[2].axvline(x=phase1_end, color='gray', linestyle='--', label='Fine-tune')
axes[2].set_title('AUC')
axes[2].set_xlabel('Epoch')
axes[2].legend()

plt.tight_layout()
plt.savefig('training_curves.png', dpi=150)
print("\n📈 Training curves saved → training_curves.png")

# ── 9. Threshold Analysis ─────────────────────────────────────
print("\n📐 Threshold Analysis:")
print(f"{'Threshold':>10} {'Sensitivity':>12} {'Specificity':>12} {'Accuracy':>10}")
for thresh in [0.3, 0.4, 0.5, 0.6, 0.7]:
    preds = (y_pred_prob > thresh).astype(int)
    tp = ((preds==1) & (y_test==1)).sum()
    fp = ((preds==1) & (y_test==0)).sum()
    fn = ((preds==0) & (y_test==1)).sum()
    tn = ((preds==0) & (y_test==0)).sum()
    sens = tp/(tp+fn) if (tp+fn)>0 else 0
    spec = tn/(tn+fp) if (tn+fp)>0 else 0
    tacc = (tp+tn)/(tp+tn+fp+fn)
    print(f"{thresh:>10.1f} {sens:>12.4f} {spec:>12.4f} {tacc:>10.4f}")

# ── 10. Convert to TFLite ─────────────────────────────────────
print("\n📦 Converting to TFLite for Flutter mobile deployment...")

def representative_dataset():
    """Provide sample data for INT8 quantization calibration"""
    for i in range(min(100, len(X_train))):
        yield [X_train[i:i+1]]

converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]

# INT8 quantization — reduces model size 4x, faster on mobile
converter.representative_dataset    = representative_dataset
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
converter.inference_input_type      = tf.float32
converter.inference_output_type     = tf.float32

try:
    tflite_model = converter.convert()
    quantization  = "INT8"
except Exception as e:
    print(f"  INT8 failed: {e} — trying float16...")
    converter2 = tf.lite.TFLiteConverter.from_keras_model(model)
    converter2.optimizations = [tf.lite.Optimize.DEFAULT]
    converter2.target_spec.supported_types = [tf.float16]
    tflite_model = converter2.convert()
    quantization  = "Float16"

with open(OUTPUT_PATH, 'wb') as f:
    f.write(tflite_model)

size_kb = os.path.getsize(OUTPUT_PATH) / 1024
print(f"  Quantization : {quantization}")
print(f"  Model size   : {size_kb:.1f} KB")
print(f"  Saved to     : {OUTPUT_PATH}")

# ── 11. Verify TFLite Model ───────────────────────────────────
print("\n🔍 Verifying TFLite model...")
interpreter = tf.lite.Interpreter(model_path=OUTPUT_PATH)
interpreter.allocate_tensors()

inp_det = interpreter.get_input_details()
out_det = interpreter.get_output_details()

print(f"  Input  shape : {inp_det[0]['shape']}")
print(f"  Output shape : {out_det[0]['shape']}")
print(f"  Input  dtype : {inp_det[0]['dtype']}")

correct = 0
anemic_scores  = []
healthy_scores = []

for i in range(len(X_test)):
    inp = np.expand_dims(X_test[i], axis=0).astype(np.float32)
    interpreter.set_tensor(inp_det[0]['index'], inp)
    interpreter.invoke()
    score = float(interpreter.get_tensor(out_det[0]['index'])[0][0])
    pred  = 1 if score > 0.5 else 0
    if pred == int(y_test[i]):
        correct += 1
    if y_test[i] == 1:
        anemic_scores.append(score)
    else:
        healthy_scores.append(score)

tflite_acc = correct / len(X_test)
print(f"\n  TFLite accuracy        : {tflite_acc:.4f}")
print(f"  Avg score — Anemic     : {np.mean(anemic_scores):.4f}  (should be > 0.5)")
print(f"  Avg score — Healthy    : {np.mean(healthy_scores):.4f}  (should be < 0.5)")

print(f"""
╔══════════════════════════════════════════════════╗
║           TRAINING COMPLETE — SAHELI             ║
╠══════════════════════════════════════════════════╣
║  Dataset     : Eyes-Defy-Anemia (Kaggle)         ║
║  Total images: {len(X):<34}║
║  Anemic      : {int(sum(y==1)):<34}║
║  Healthy     : {int(sum(y==0)):<34}║
╠══════════════════════════════════════════════════╣
║  Test Accuracy   : {acc:.4f}                        
║  Test AUC        : {auc:.4f}                        
║  Sensitivity     : {sensitivity:.4f}                
║  Specificity     : {specificity:.4f}                
║  TFLite Accuracy : {tflite_acc:.4f}                 
║  Model Size      : {size_kb:.1f} KB                  
╠══════════════════════════════════════════════════╣
║  Output: assets/models/anaemia_model.tflite      ║
╚══════════════════════════════════════════════════╝
""")