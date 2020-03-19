#!/usr/bin/python3

# 8 bit RLE compressor
# written by Doug Fraker 2020
# for SNES background maps (and other things)
# all 8 bit units, and 8-16 bit headers

# non-planar and planar combined version
# (planar = split all even and odd bytes)
# it tests both and outputs only the smaller

# eof byte (last of file) of F0 indicates
# non-planar. 
# eof byte FF = planar, which is what we 
# expect for SNES maps.

# one byte header ----
# MM CCCCCC
# M - mode, C - count (+1)
# 0 - literal, C+1 values (1-64)
# 1 - rle run, C+1 times (1-64)
# 2 - rle run, add 1 each pass, C+1 times (1-64)
# 3 - extend the value count to 2 bytes
# 00 lit, 40 rle, 80 plus, F0 special

# two byte header ----
# 11 MM CCCC (high) CCCCCCCC (low)
# M - mode (as above), C - count (+1)
# count 1-4096
# c0 lit big, d0 = rle big, e0 = plus big
# F0 - end of data, non-planar
# FF - end of data, planar

# input binary up to 32768 bytes


# note, planar expects an even # of bytes, 
# and will pad a zero 00 at the end
# of an odd number of input bytes.


import sys
import os





def try_rle(out_array):
    global index
    global filesize
    global count
    global index2
    
    oldindex = index
    count = 0
    byte1 = 0
    byte2 = 0
    byte3 = 0
    while(index < filesize):
        if(count >=  4095):
            break
        if(in_array[index-1] == in_array[index]):
            count = count + 1
            index = index + 1
        else:
            break    
    if (count > 0): # zero is better, leaving it.
        #output to the out array
        if(count > 31): # 2 byte header d0 00
            byte1 = ((count >> 8) & 0x0f) + 0xd0
            byte2 = count & 0xff
            byte3 = in_array[index-1]
            out_array[index2] = byte1
            index2 = index2 + 1
            out_array[index2] = byte2
            index2 = index2 + 1
            out_array[index2] = byte3
            index2 = index2 + 1
            
        else: # 1 byte header 40
            byte1 = (count & 0x3f) + 0x40
            byte2 = in_array[index-1]
            out_array[index2] = byte1
            index2 = index2 + 1
            out_array[index2] = byte2
            index2 = index2 + 1
        index = index + 1
    else:
        count = 0 
        index = oldindex
        
        
def try_plus(out_array):
    global index
    global filesize
    global count
    global index2
    oldindex = index
    count = 0
    start_value = in_array[index-1]
    byte1 = 0
    byte2 = 0
    byte3 = 0
    while(index < filesize):
        if(count >=  255): # in the 8 bit version 4095 doesn't make sense
            break
        if(in_array[index-1] == in_array[index] - 1): #what about wrap around ?
            count = count + 1
            index = index + 1
        else:
            break
    if (count > 0): # zero is better, leaving it.
        #output to the out array
        if(count > 31): # 2 byte header e0 00
            byte1 = ((count >> 8) & 0x0f) + 0xe0
            byte2 = count & 0xff
            byte3 = start_value
            out_array[index2] = byte1
            index2 = index2 + 1
            out_array[index2] = byte2
            index2 = index2 + 1
            out_array[index2] = byte3
            index2 = index2 + 1
        else: # 1 byte header 80
            byte1 = (count & 0x3f) + 0x80
            byte2 = start_value
            out_array[index2] = byte1
            index2 = index2 + 1
            out_array[index2] = byte2
            index2 = index2 + 1
        index = index + 1
    else:
        count = 0 
        index = oldindex
        
        
def do_literal(out_array):
    global index
    global filesize
    global count    
    global index2
    byte1 = 0
    byte2 = 0
    byte3 = 0
    start_index = index-1
    
    count = 0
    index = index + 1
    while(index < filesize):
        if(count >=  4094): # 2 less to fix possible error
            break
        if((in_array[index-2] == in_array[index-1]) and (in_array[index-1] == in_array[index])):
            break
        if(((in_array[index-2] == in_array[index-1] - 1)) and (in_array[index-1] == in_array[index] - 1)):
            break
        count = count + 1
        index = index + 1
    
    # back up 1, found a repeat, or repeat + 1
    count = count - 1
    index = index - 1
    nearend = filesize - index
    if (nearend < 2):
        #end of file, dump rest
        if (nearend == 1):
            count = count + 1
            index = index + 1
        count = count + 1
        index = index + 1
     
    if (count >= 0):
        #output to the out array
        count2 = count + 1
        if(count > 31): # 2 byte header c0 00
            byte1 = ((count >> 8) & 0x0f) + 0xc0
            byte2 = count & 0xff
            out_array[index2] = byte1
            index2 = index2 + 1
            out_array[index2] = byte2
            index2 = index2 + 1
            for i in range (0,count2):
                byte3 = in_array[start_index]
                out_array[index2] = byte3
                index2 = index2 + 1
                start_index = start_index + 1
        else: # 1 byte header 00
            byte1 = (count & 0x3f)
            out_array[index2] = byte1
            index2 = index2 + 1
            for i in range (0,count2):
                byte2 = in_array[start_index]
                out_array[index2] = byte2
                index2 = index2 + 1
                start_index = start_index + 1
                





filename = sys.argv[1]
newname = filename[0:-4] + ".rle"

oldfile = open(filename, 'rb')
newfile = open(newname, 'wb')  # warning, this may overwrite old file !
filesize = os.path.getsize(filename)
print("input filesize = " + str(filesize))
if(filesize > 32768):
    exit("error, too large. File should be <= 32768 bytes.")
    
if(filesize < 3):
    exit("error, file too small.")

in_array = [0] * 32768
in_array_P = [0] * 32768
out_array_nonP = [0] * 33000 # a little extra, just in case
out_array_P = [0] * 33000

#copy to array
for i in range (0, filesize):
    in_array[i] = ord(oldfile.read(1))

    
# first try non-planar...

index = 1 # start at 1, subtract
index2 = 0
non_pl_size = 0
count = 0
   
        
#main
while(index < filesize):
    count = 0

    try_rle(out_array_nonP)
    # returns with count > 1 if successful

    if(count == 0):
        try_plus(out_array_nonP)
        # returns with count > 1 if successful
        
        if(count == 0):
            do_literal(out_array_nonP)
            


# do final literal, last byte
if(index == filesize):
    #we need 1 more literal
    out_array_nonP[index2] = 0
    index2 = index2 + 1
    byte1 = in_array[filesize-1]
    out_array_nonP[index2] = byte1
    index2 = index2 + 1


# put a final f0 - non-planar symbol
out_array_nonP[index2] = 0xf0
index2 = index2 + 1
non_pl_size = index2


# try again with planar...


filesize_half = (filesize + 1) // 2 # round up, divide by 2
filesize = filesize_half * 2
split_array = [0] *  16384
split_array2 = [0] *  16384

# split the array
for i in range (0, filesize_half):
	j = i * 2
	k = j + 1
	split_array[i] = in_array[j] # even bytes
	split_array2[i] = in_array[k] # odd bytes
	
# copy them back
# (so I don't have to change the rest of the code)

for i in range (0, filesize_half):
	in_array_P[i] = split_array[i]
	j = i + filesize_half
	in_array_P[j] = split_array2[i] 
    

# copy out to another array
# so I don't have to refactor the original code.
#for i in range(0, index2):
#    out_array_nonP[i] = out_array[i]
    


#copy planar to original
for i in range (0, filesize):
    in_array[i] = in_array_P[i]

#reset and rerun planar  
count = 0
index2 = 0
index = 1



#main again, planar
while(index < filesize):
    count = 0

    try_rle(out_array_P)
    # returns with count > 1 if successful

    if(count == 0):
        try_plus(out_array_P)
        # returns with count > 1 if successful
        
        if(count == 0):
            do_literal(out_array_P)
            


# do final literal, last byte
if(index == filesize):
    #we need 1 more literal
    out_array_P[index2] = 0
    index2 = index2 + 1
    byte1 = in_array[filesize-1]
    out_array_P[index2] = byte1
    index2 = index2 + 1



# put a final ff - planar symbol
out_array_P[index2] = 0xff

# note out_array_P[] is the Planar version
# non-planar is out_array_nonP[]

index2 = index2 + 1  
pl_size = index2


print("planar out size = " + str(pl_size))
print("non-planar out size = " + str(non_pl_size))

a = 0

if(non_pl_size <= pl_size): #3 is smaller, non-planar
    print("using non-planar...")
    for i in range (0, non_pl_size):
        byte1 = out_array_nonP[i]
        newfile.write(bytes([byte1]))
    a = non_pl_size
else:
    print("using planar...")
    for i in range (0, pl_size):
        byte1 = out_array_P[i]
        newfile.write(bytes([byte1]))
    a = pl_size


# output percent of original the output is.
b = 100.0 * a / filesize
b = round(b, 2)
print("  new filesize = " + str(a))
print("  compared to orig = " + str(b) + "%")

# close the files.
oldfile.close
newfile.close






