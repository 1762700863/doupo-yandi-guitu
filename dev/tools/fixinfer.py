import subprocess,re,sys
for it in range(15):
    out=subprocess.run(["timeout","120",sys.argv[1],"--headless","--path",sys.argv[2],"--check-only","--quit"],capture_output=True,text=True)
    txt=out.stdout+out.stderr
    lines=txt.splitlines()
    fixes=[]
    for i,l in enumerate(lines):
        m=re.search(r'Cannot infer the type of "(\w+)"',l)
        if m:
            for k in range(i+1,min(i+4,len(lines))):
                m2=re.search(r'res://(scripts/[\w_]+\.gd):(\d+)',lines[k])
                if m2:
                    fixes.append((m2.group(1),int(m2.group(2)),m.group(1)));break
    if not fixes:
        print("no more infer errors");break
    done=0
    for f,ln,name in set(fixes):
        p=sys.argv[2]+"/"+f
        L=open(p).read().split("\n")
        new=re.sub(r'\b(var|const)\s+%s\s*:='%name, r'\1 %s ='%name, L[ln-1])
        if new==L[ln-1]:
            new=re.sub(r'for\s+%s\s*:'%name,'for %s:'%name,L[ln-1])
        if new!=L[ln-1]:
            L[ln-1]=new;done+=1
            open(p,"w").write("\n".join(L))
        else:
            print("couldnt fix",f,ln,name,L[ln-1].strip())
    print("iter",it,"fixed",done)
    if done==0:break
