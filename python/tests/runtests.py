import glob, os
for i in glob.glob('test*.py'):
    os.system('python %s' % i)
os.system('rm d_parser*')
