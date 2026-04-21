from pathlib import Path
import random
import shutil
import csv

# Path configuration
SOURCE_ROOT = Path(
    r"E:\A_connected environments\DLSN\Hass Avocado Ripening Photographic Dataset\Avocado Ripening Dataset"
)

OUTPUT_ROOT = Path(
    r"E:\A_connected environments\DLSN\Avocado_dataset"
)

# Adjustable parameters

TRAIN_RATIO = 0.8
RANDOM_SEED = 42

# Set to an integer to limit each final class size
# Set to None to use all available images
MAX_IMAGES_PER_CLASS = 2800

# If True, the output folder will be deleted and rebuilt
CLEAR_OUTPUT_FIRST = True

SUPPORTED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}

# New stage mapping:
# 1,2 -> unripe
# 3   -> ready
# 4,5 -> overripe
STAGE_TO_CLASS = {
    "1": "unripe",
    "2": "unripe",
    "3": "ready",
    "4": "overripe",
    "5": "overripe",
}

# Helper functions

def is_image_file(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() in SUPPORTED_IMAGE_EXTENSIONS


def reset_output_directory(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def ensure_directory(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def parse_image_filename(path: Path):
    """
    Expected filename format:
    T10_d01_002_a_1.jpg

    Parsed fields:
    storage = T10
    day = d01
    sample = 002
    side = a
    stage = 1

    Returns a dictionary like:
    {
        "path": Path(...),
        "storage": "T10",
        "day": "d01",
        "sample": "002",
        "side": "a",
        "stage": "1",
        "class_name": "unripe",
        "group_id": "T10_d01_002_1"
    }
    """
    stem = path.stem
    parts = stem.split("_")

    if len(parts) < 5:
        return None

    storage = parts[0]
    day = parts[1]
    sample = parts[2]
    side = parts[3]
    stage = parts[4]

    if not day.startswith("d"):
        return None

    if side not in {"a", "b"}:
        return None

    if stage not in STAGE_TO_CLASS:
        return None

    class_name = STAGE_TO_CLASS[stage]

    # Keep the paired views (a/b) of the same sample and stage together
    group_id = f"{storage}_{day}_{sample}_{stage}"

    return {
        "path": path,
        "storage": storage,
        "day": day,
        "sample": sample,
        "side": side,
        "stage": stage,
        "class_name": class_name,
        "group_id": group_id,
    }


def collect_image_records(source_root: Path):
    records = []
    skipped_files = []

    for path in source_root.rglob("*"):
        if not is_image_file(path):
            continue

        parsed = parse_image_filename(path)
        if parsed is None:
            skipped_files.append(str(path))
        else:
            records.append(parsed)

    return records, skipped_files


def group_records_by_class_and_group(records):
    grouped = {
        "unripe": {},
        "ready": {},
        "overripe": {},
    }

    for record in records:
        class_name = record["class_name"]
        group_id = record["group_id"]
        grouped[class_name].setdefault(group_id, []).append(record)

    return grouped


def limit_groups_by_image_count(group_dict, max_images=None):
    """
    group_dict structure:
    {
        "group_id_1": [record1, record2],
        "group_id_2": [record3, record4],
        ...
    }

    If max_images is None, keep all groups.
    Otherwise, shuffle groups and keep adding groups until the image count
    reaches or slightly exceeds max_images.
    """
    group_keys = list(group_dict.keys())
    random.shuffle(group_keys)

    if max_images is None:
        return {key: group_dict[key] for key in group_keys}

    selected = {}
    image_count = 0

    for key in group_keys:
        group_size = len(group_dict[key])
        if image_count >= max_images:
            break
        selected[key] = group_dict[key]
        image_count += group_size

    return selected


def split_groups_into_train_test(group_dict, train_ratio=0.8):
    """
    Split by group to avoid placing paired images (a/b) into different subsets.
    """
    group_keys = list(group_dict.keys())
    random.shuffle(group_keys)

    total_groups = len(group_keys)
    if total_groups == 0:
        return {}, {}

    if total_groups == 1:
        return {group_keys[0]: group_dict[group_keys[0]]}, {}

    train_group_count = int(total_groups * train_ratio)

    if train_group_count <= 0:
        train_group_count = 1
    if train_group_count >= total_groups:
        train_group_count = total_groups - 1

    train_keys = set(group_keys[:train_group_count])
    test_keys = set(group_keys[train_group_count:])

    train_groups = {key: group_dict[key] for key in train_keys}
    test_groups = {key: group_dict[key] for key in test_keys}

    return train_groups, test_groups


def flatten_group_dictionary(group_dict):
    records = []
    for group_records in group_dict.values():
        records.extend(group_records)
    return records


def copy_records_to_output(records, subset_name, class_name):
    target_dir = OUTPUT_ROOT / subset_name / class_name
    ensure_directory(target_dir)

    copied_paths = []
    for record in records:
        source_path = record["path"]
        destination_path = target_dir / source_path.name
        shutil.copy2(source_path, destination_path)
        copied_paths.append(destination_path)

    return copied_paths


# Main pipeline

def main():
    random.seed(RANDOM_SEED)

    if CLEAR_OUTPUT_FIRST:
        reset_output_directory(OUTPUT_ROOT)
    else:
        ensure_directory(OUTPUT_ROOT)

    print("Scanning source dataset...")
    records, skipped_files = collect_image_records(SOURCE_ROOT)

    if not records:
        raise RuntimeError(
            "No valid images were found. Please check the source path and filename format."
        )

    print(f"Successfully parsed images: {len(records)}")
    print(f"Skipped files: {len(skipped_files)}")

    if skipped_files:
        skipped_file_path = OUTPUT_ROOT / "skipped_files.txt"
        with open(skipped_file_path, "w", encoding="utf-8") as file:
            for item in skipped_files:
                file.write(item + "\n")
        print(f"Skipped file list saved to: {skipped_file_path}")

    grouped_records = group_records_by_class_and_group(records)

    summary_rows = []
    total_train_images = 0
    total_test_images = 0

    for class_name in ["unripe", "ready", "overripe"]:
        class_groups = grouped_records[class_name]

        original_group_count = len(class_groups)
        original_image_count = sum(len(group) for group in class_groups.values())

        selected_groups = limit_groups_by_image_count(
            class_groups,
            max_images=MAX_IMAGES_PER_CLASS
        )

        selected_group_count = len(selected_groups)
        selected_image_count = sum(len(group) for group in selected_groups.values())

        train_groups, test_groups = split_groups_into_train_test(
            selected_groups,
            train_ratio=TRAIN_RATIO
        )

        train_records = flatten_group_dictionary(train_groups)
        test_records = flatten_group_dictionary(test_groups)

        copied_train = copy_records_to_output(train_records, "training", class_name)
        copied_test = copy_records_to_output(test_records, "testing", class_name)

        total_train_images += len(copied_train)
        total_test_images += len(copied_test)

        summary_rows.append({
            "class_name": class_name,
            "original_group_count": original_group_count,
            "original_image_count": original_image_count,
            "selected_group_count": selected_group_count,
            "selected_image_count": selected_image_count,
            "train_image_count": len(copied_train),
            "test_image_count": len(copied_test),
        })

        print(
            f"[{class_name}] "
            f"original_images={original_image_count}, "
            f"selected_images={selected_image_count}, "
            f"train_images={len(copied_train)}, "
            f"test_images={len(copied_test)}"
        )

    summary_csv_path = OUTPUT_ROOT / "dataset_summary.csv"
    with open(summary_csv_path, "w", newline="", encoding="utf-8-sig") as csv_file:
        writer = csv.DictWriter(
            csv_file,
            fieldnames=[
                "class_name",
                "original_group_count",
                "original_image_count",
                "selected_group_count",
                "selected_image_count",
                "train_image_count",
                "test_image_count",
            ]
        )
        writer.writeheader()
        writer.writerows(summary_rows)

    print("\nProcessing completed successfully.")
    print(f"Output directory: {OUTPUT_ROOT}")
    print(f"Total training images: {total_train_images}")
    print(f"Total testing images: {total_test_images}")
    print(f"Summary file: {summary_csv_path}")

    print("\nFinal folder structure:")
    print(OUTPUT_ROOT / "training" / "unripe")
    print(OUTPUT_ROOT / "training" / "ready")
    print(OUTPUT_ROOT / "training" / "overripe")
    print(OUTPUT_ROOT / "testing" / "unripe")
    print(OUTPUT_ROOT / "testing" / "ready")
    print(OUTPUT_ROOT / "testing" / "overripe")


if __name__ == "__main__":
    main()