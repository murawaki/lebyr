# -*- mode: Makefile -*-
#
# ussage: make -f THIS_FILE INPUT=x OUTPUT=y ...
#

# default configurations
SHARD:=10
ITER:=5
TYPE:=map
INPUT:=train.bz2
OUTPUT:=output.$(TYPE)
TMPDIR:=/tmp

BASEDIR:=/home/murawaki/research/lebyr/noun
SPLIT_PROGRAM:=perl $(BASEDIR)/split-train.pl --shard=$(SHARD) --compressed --compress
TRAIN_PROGRAM:=perl $(BASEDIR)/train-mp.pl --type=$(TYPE) --iter=1 --debug --compressed
MERGE_PROGRAM:=perl $(BASEDIR)/merge-mp.pl --type=$(TYPE) --debug

define shard_dummy
$(TMPDIR)/shard.$(1).bz2: $(TMPDIR)/shard.$(shell expr $(1) - 1).bz2
endef

define parallel_train_init
$(TMPDIR)/each.1.$(1).$(TYPE): $(TMPDIR)/shard.$(1).bz2
	$(TRAIN_PROGRAM) --input=$(TMPDIR)/shard.$(1).bz2 --output=$(TMPDIR)/each.1.$(1).$(TYPE)
endef

define parallel_train_each
$(TMPDIR)/each.$(1).$(2).$(TYPE): $(TMPDIR)/merged.$(shell expr $(1) - 1) $(TMPDIR)/shard.$(2).bz2
	$(TRAIN_PROGRAM) --input=$(TMPDIR)/shard.$(2).bz2 --init=$(TMPDIR)/merged.$(shell expr $(1) - 1) --output=$(TMPDIR)/each.$(1).$(2).$(TYPE)
endef

define merge_mps
$(TMPDIR)/merged.$(1): $(foreach y,$(shell seq 1 $(SHARD)),$(TMPDIR)/each.$(1).$(y).$(TYPE))
	$(MERGE_PROGRAM) --dir=$(TMPDIR) --prefix=each.$(1). --output=$(TMPDIR)/merged.$(1)
endef

$(foreach x,$(shell seq 2 $(SHARD)), \
  $(eval $(call shard_dummy,$(x))))
$(foreach x,$(shell seq 1 $(ITER)), \
  $(eval $(call merge_mps,$(x))))
$(foreach x,$(shell seq 1 $(SHARD)), \
  $(eval $(call parallel_train_init,$(x))))
$(foreach x,$(shell seq 2 $(ITER)), \
  $(foreach y,$(shell seq 1 $(SHARD)), \
    $(eval $(call parallel_train_each,$(x),$(y)))))

.PHONY : all clean
all : $(OUTPUT)
$(OUTPUT) : $(TMPDIR)/merged.$(ITER)
	mv $< $@
$(TMPDIR)/shard.1.bz2 : $(INPUT)
	mkdir -p $(TMPDIR)
	$(SPLIT_PROGRAM) --input=$< --prefix=$(TMPDIR)/shard

clean:
	rm -rf $(TMPDIR)
