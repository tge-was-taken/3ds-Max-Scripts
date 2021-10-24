fn floatSwap2 f = (
	i = bit.floatAsInt f
	h = bit.intashex i
	while h.count < 8 do h = "0" + h
	
	s = (substring h 7 2) + (substring h 5 2) + (substring h 3 2) + (substring h 1 2)
	bit.intAsFloat (bit.hexasint s)
)

fn PrintOffset fstream Name = (
	format "% Offset 0x%\n" Name (bit.intashex(ftell fstream))
)

fn ReadEndianShort fstream sign = (
	short = readshort fstream sign
	if (IsBigEndian) then short = bit.swapBytes short 1 2
	return short
)

fn ReadEndianLong fstream sign = (
	long = readlong fstream sign
	if (IsBigEndian) then 
	(
		long = bit.swapBytes long 1 4
		long = bit.swapBytes long 2 3
	)
	return long
)

fn ReadPointer fstream = (
	ptr = ReadEndianLong fstream #unsigned
	if (ptr != 0) then ptr -= Key
	return ptr as integer
)

fn ReadEndianFloat fstream = (
	floatValue = readfloat fstream
	if (IsBigEndian) then floatValue = floatSwap2(floatValue)
	return floatValue
)

fn ReadFixedString bstream fixedLen = (
    local str = ""
    for i = 1 to fixedLen do
    (
        str += bit.intAsChar (ReadByte bstream #unsigned)
    )
    str
)

fn ReadVector3 fstream = (
	return [(ReadEndianFloat fstream), (ReadEndianFloat fstream), (ReadEndianFloat fstream)]
)

fn ReadVector2 fstream = (
	return [(ReadEndianFloat fstream), (ReadEndianFloat fstream), 0]
)

fn ReadRGBA fstream = (
	return #((readbyte fstream #unsigned), (readbyte fstream #unsigned), (readbyte fstream #unsigned), (readbyte fstream #unsigned))
)

fn ReadBAMSVector3 fstream = (
	return [(BAMS2Deg * ReadEndianLong f #signed), (BAMS2Deg * ReadEndianLong f #signed), (BAMS2Deg * ReadEndianLong f #signed)]
)