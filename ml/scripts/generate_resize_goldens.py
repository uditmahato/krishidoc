"""Generate small numerical fixtures with the installed training image library."""
import json
from pathlib import Path
from PIL import Image, __version__

rows = []
for w,h,ow,oh in [(17,13,7,5),(3,2,9,6),(29,17,4,3),(1,11,1,4),(11,1,4,1),(8,6,8,6)]:
    rgb = [((x*31+y*7)%256,(x*3+y*47)%256,(x*73+y*11)%256) for y in range(h) for x in range(w)]
    image = Image.new('RGB',(w,h))
    image.putdata(rgb)
    resized = image.resize((ow,oh),Image.Resampling.BILINEAR)
    rows.append({'width':w,'height':h,'outputWidth':ow,'outputHeight':oh,
                 'rgb':[v for pixel in resized.getdata() for v in pixel]})
destination = Path(__file__).resolve().parents[2] / 'app/test/fixtures/training_resize.json'
destination.parent.mkdir(parents=True,exist_ok=True)
destination.write_text(json.dumps({'pillow_version':__version__,'cases':rows},indent=2))
print(destination)
