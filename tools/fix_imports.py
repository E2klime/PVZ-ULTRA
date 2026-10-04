"""Enable mipmaps for painted sprites (drawn at 0.5x) and FX/tiles.
Run after a first `godot --import`, then import again."""
import glob, os, re
root = os.path.join(os.path.dirname(__file__), '..')
n = 0
for pat in ('assets/sprites/**/*.png.import', 'assets/tiles/**/*.png.import', 'assets/ui/**/*.png.import'):
    for f in glob.glob(os.path.join(root, pat), recursive=True):
        s = open(f).read()
        t = s.replace('mipmaps/generate=false', 'mipmaps/generate=true')
        if t != s:
            open(f, 'w').write(t)
            n += 1
print('mipmaps enabled for', n, 'textures')
