#!/usr/bin/env python3
import argparse, concurrent.futures, os, pathlib, subprocess, json
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--all',action='store_true');p.add_argument('--levels',nargs='+',help='Specific level IDs to play');p.add_argument('--jobs',type=int,default=2);p.add_argument('--strategy',default='standard',choices=['standard','strong']);p.add_argument('--out',default='/tmp/garden-defense-tests');p.add_argument('--timeout',type=int,default=240,help='wall-clock seconds per level');a=p.parse_args()
root=pathlib.Path(__file__).resolve().parents[2];out=pathlib.Path(a.out);out.mkdir(parents=True,exist_ok=True)
levels=[f'{w}_{n:02}' for w in ['lawn','pool','night','desert','roof','frost','factory','moon'] for n in range(1,26)] if a.all else ['lawn_01','lawn_06','lawn_15','lawn_22','lawn_25','pool_06','night_21','desert_16','roof_17','frost_21','factory_25','moon_24','moon_25']
if a.levels: levels=a.levels
def run(level):
 home=out/('home_'+level);home.mkdir(exist_ok=True);env=os.environ.copy();env['HOME']=str(home)
 command=[a.godot,'--headless','--path',str(root),'--fixed-fps','60','res://tools/tests/campaign_bot.tscn','--',level,'standard',a.strategy]
 try:
  proc=subprocess.run(command,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=a.timeout)
  text=proc.stdout;(out/(level+'.log')).write_text(text);lines=[s for s in text.splitlines() if s.startswith('BOT:')]
  result={'level':level,'exit':proc.returncode,'result':lines[-1] if lines else 'NO RESULT','errors':'ERROR:' in text or 'SCRIPT ERROR' in text or 'leaked at exit' in text}
 except subprocess.TimeoutExpired as ex: result={'level':level,'exit':124,'result':'WALL-CLOCK TIMEOUT','errors':True}
 print(result,flush=True);return result
with concurrent.futures.ThreadPoolExecutor(max_workers=a.jobs) as pool: results=list(pool.map(run,levels))
(out/'summary.json').write_text(json.dumps(results,indent=2))
raise SystemExit(1 if any(r['exit']!=0 or r['errors'] for r in results) else 0)
