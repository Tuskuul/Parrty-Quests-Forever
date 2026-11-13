"""Prepare addon/project icon sizes from the approved artwork. Requires Pillow."""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
MASTER=ROOT/'docs'/'artwork'/'PartyQuestsForever-original.png'
with Image.open(MASTER) as source:
    icon=source.convert('RGBA')
    icon.resize((512,512),Image.Resampling.LANCZOS).save(ROOT/'docs'/'project-icon.png')
    icon.resize((256,256),Image.Resampling.LANCZOS).save(ROOT/'Assets'/'Icon.tga')
