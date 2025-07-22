#!/usr/bin/env python3
import os, argparse
import h5py
import numpy as np

def write_mif(fname, data, width):
    depth = len(data)
    with open(fname,'w') as f:
        f.write(f"WIDTH={width};\nDEPTH={depth};\n"
                "ADDRESS_RADIX=UNS;\nDATA_RADIX=UNS;\nCONTENT BEGIN\n")
        for i,v in enumerate(data):
            if v<0: v = (1<<width)+v
            f.write(f"  {i} : {v};\n")
        f.write("END;\n")

def quantize(arr, bits):
    mx = np.max(np.abs(arr))
    if mx==0: return np.zeros_like(arr,dtype=int)
    scale = (2**(bits-1)-1)/mx
    return np.round(arr*scale).astype(int)

if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--h5',    required=True)
    p.add_argument('--out',   default='mifs')
    p.add_argument('--bits',  type=int,default=8)
    args=p.parse_args()

    os.makedirs(args.out,exist_ok=True)
    f=h5py.File(args.h5,'r')
    root = f.get('model_weights', f)
    for lname, grp in root.items():
        # some versions nest under another group
        sub = grp.get(lname, grp)
        for dname, ds in sub.items():
            if isinstance(ds, h5py.Dataset):
                arr = ds[()]
                flat = arr.flatten()
                q    = quantize(flat, args.bits)
                safe = f"{lname}_{dname}".replace(':','_')
                write_mif(f"{args.out}/{safe}.mif", q, args.bits)
                print("Wrote", safe, "(", flat.size, "entries)")
    f.close()
