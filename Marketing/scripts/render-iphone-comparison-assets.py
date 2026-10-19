"""Original editorial decision diagram. Not a product screenshot or test result."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, PngImagePlugin
import json
ROOT=Path(__file__).resolve().parents[1] / 'public/images/guides'
INK='#f6edff'; MUTED='#bdb8c7'; LAVENDER='#c3aaff'; RULE='#403749'; BG='#17131c'
REG='/System/Library/Fonts/Supplemental/Arial.ttf'
BOLD='/System/Library/Fonts/Supplemental/Arial Bold.ttf'
def text(d,xy,s,size=40,bold=False,fill=INK): d.text(xy,s,font=ImageFont.truetype(BOLD if bold else REG,size),fill=fill)
def diagram():
 im=Image.new('RGB',(1200,676),BG); d=ImageDraw.Draw(im)
 text(d,(58,44),'What needs to work?',55,True)
 d.line((58,134,1142,134),fill=RULE,width=2)
 d.line((600,170,600,615),fill=RULE,width=2)
 d.line((58,390,1142,390),fill=RULE,width=2)
 # Camera framing icon.
 d.rounded_rectangle((67,198,127,239),8,outline=LAVENDER,width=4)
 d.ellipse((86,208,108,230),outline=LAVENDER,width=3)
 text(d,(67,267),'Short clips',48,True)
 # Pauses and speech: an abstract waveform, not measured data.
 for x,h in [(657,12),(672,35),(687,54),(702,24),(717,45)]:
  d.line((x,222-h//2,x,222+h//2),fill=LAVENDER,width=5)
 text(d,(654,267),'Speech following',48,True)
 # A remote control with simple buttons.
 d.rounded_rectangle((72,426,116,490),10,outline=LAVENDER,width=4)
 d.ellipse((88,438,100,450),fill=LAVENDER)
 d.line((84,467,104,467),fill=LAVENDER,width=3)
 text(d,(67,522),'Production controls',43,True)
 # Sharing/export tray.
 d.line((665,465,665,487,715,487,715,465),fill=LAVENDER,width=4)
 d.line((690,470,690,430),fill=LAVENDER,width=4)
 d.line((675,447,690,430,705,447),fill=LAVENDER,width=4)
 text(d,(654,522),'Editing & publishing',43,True)
 for width in (480,800,1200):
  im.resize((width,round(width*676/1200)),Image.Resampling.LANCZOS).save(ROOT/f'iphone-app-comparison-{width}.webp',quality=88)
 im.resize((640,361),Image.Resampling.LANCZOS).save(ROOT/'iphone-app-comparison-thumbnail.webp',quality=86)
 social=Image.new('RGB',(1200,630),'#0f0f0f'); d=ImageDraw.Draw(social)
 text(d,(64,48),'teleprompterpal.',30,True,LAVENDER)
 text(d,(64,147),'Best teleprompter',69,True)
 text(d,(64,229),'apps for iPhone',69,True)
 d.line((64,350,1136,350),fill=RULE,width=2)
 text(d,(64,398),'Free limits. Recording workflows.',35,False,MUTED)
 text(d,(64,450),'Dated sources. Clearly labeled evidence.',35,False,MUTED)
 text(d,(64,551),'Teleprompter Pal team',25,False,LAVENDER)
 meta=PngImagePlugin.PngInfo(); meta.add_text('Description','Original editorial graphic for the iPhone app comparison. Not a product screenshot, test result or independent review.')
 social.save(ROOT/'best-teleprompter-apps-for-iphone.png',pnginfo=meta,optimize=True)
 (ROOT/'provenance.json').write_text(json.dumps({'kind':'original_programmatic_editorial_diagram','generator':str(Path(__file__).resolve()),'created':'2026-10-19','purpose':'Recording-priority cover and matching guide thumbnail; separate original social image.','not_evidence':'Does not depict measured performance, vendor UI or app screenshots.','fonts':'System Arial; no third-party product imagery.','palette':'Existing Pal dark/lavender palette.'},indent=2)+'\n')
if __name__=='__main__': diagram()
