#
# Makefile
#
# $Revision: 1.1 $
#

DPARSERDIR= ..
GRAMMAR= verilog.g
DPARSEFLAGS= -l -v

TARGET= v
CSRCS= main.cpp vparse.cpp ambig.cpp
OBJS= $(CSRCS:.cpp=.o) $(GRAMMAR).d_parser.o
INCDIRSS= -I$(DPARSERDIR)
CFLAGS= -g $(INCDIRSS)
CPPFLAGS = $(CFLAGS)

#########

target: $(TARGET)

##########

$(TARGET): $(OBJS)
	$(CXX) $(CFLAGS) -o $@ $(OBJS) \
		-L$(DPARSERDIR) -ldparse

$(GRAMMAR).d_parser.cpp: $(GRAMMAR)
	$(DPARSERDIR)/make_dparser $(DPARSEFLAGS) $(GRAMMAR)

lint:
	lint $(CFLAGS) $(CSRCS)

test:	$(TARGET)
	./verilog_tests
	grep succeeded log.txt | wc -l
	grep failed log.txt | wc -l

clean:
	rm -f $(GRAMMAR).d_parser.cpp $(TARGET) $(OBJS) log.txt
