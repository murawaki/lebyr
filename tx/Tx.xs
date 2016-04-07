#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#include <string>
#include <fstream>
#include <vector>
#include "tx.hpp"

using namespace std;

int tx_free(int txi){
    delete INT2PTR(tx_tool::tx *, txi);
}

int tx_open(char *filename){
    tx_tool::tx *txp = new tx_tool::tx;
    if (txp->read(filename) == -1){
	delete txp;
	return 0;
    }
    return PTR2IV(txp);
}

SV *tx_prefixSearch(int txi, SV *src){
    tx_tool::tx *txp = INT2PTR(tx_tool::tx *, txi);

    char *head = SvPV_nolen(src);
    size_t retLen;    
    const tx_tool::uint id = txp->prefixSearch(head, strlen(head), retLen);

    if (id != tx_tool::tx::NOTFOUND){
	string retKey;
	size_t retLen = txp->reverseLookup(id, retKey);
	return newSVpvn(retKey.c_str(), retLen);
    }else{
	return &PL_sv_undef;
    }
}

SV *tx_search(int txi, SV *src, int searchType){
    AV *results;
    tx_tool::tx *txp = INT2PTR(tx_tool::tx *, txi);

    char *head = SvPV_nolen(src);

    vector<string> ret;
    vector<tx_tool::uint> retID;
    tx_tool::uint retNum;

    if (searchType == 0) {
	retNum = txp->commonPrefixSearch(head, strlen(head), ret, retID);
    } else {
	retNum = txp->predictiveSearch(head, strlen(head), ret, retID);
    }

    results = newAV();
    for (size_t i = 0; i < ret.size(); i++){
	av_push(results, newSVpvn(ret[i].c_str(), ret[i].size()));
    }
    return newRV((SV *) results);
}

SV *tx_search_id(int txi, SV *src, int searchType){
    AV *results;
    tx_tool::tx *txp = INT2PTR(tx_tool::tx *, txi);

    char *head = SvPV_nolen(src);

    vector<tx_tool::uint> retLen;
    vector<tx_tool::uint> retID;
    tx_tool::uint retNum;

    if (searchType == 0) {
	retNum = txp->commonPrefixSearch(head, strlen(head), retLen, retID);
    } else {
	retNum = txp->predictiveSearch(head, strlen(head), retLen, retID);
    }

    results = newAV();
    for (size_t i = 0; i < retLen.size(); i++){
	av_push(results, newSViv((int) retID[i]));
    }
    return newRV((SV *) results);
}

SV *tx_reverseLookup(int txi, SV *id){
    tx_tool::tx *txp = INT2PTR(tx_tool::tx *, txi);

    tx_tool::uint id2 = (tx_tool::uint) SvIV (id);

    string retKey;
    size_t retLen = txp->reverseLookup(id2, retKey);
    return newSVpvn(retKey.c_str(), retLen);
}

SV *tx_getKeyNum(int txi){
    tx_tool::tx *txp = INT2PTR(tx_tool::tx *, txi);

    tx_tool::uint num = txp->getKeyNum();
    return newSViv((int) num);
}


MODULE = Text::Trie::Tx		PACKAGE = Text::Trie::Tx		

int
xs_free(txi)
    int  txi;
CODE:
    RETVAL = tx_free(txi);
OUTPUT:
    RETVAL

int
xs_open(filename)
   char *filename
CODE:
   RETVAL = tx_open(filename);
OUTPUT:
   RETVAL

SV *
xs_prefixSearch(txi, src)
   int txi;
   SV *src;
CODE:
   RETVAL = tx_prefixSearch(txi, src);
OUTPUT:
   RETVAL

SV *
xs_commonPrefixSearch(txi, src)
   int txi;
   SV *src;
CODE:
   RETVAL = tx_search(txi, src, 0);
OUTPUT:
   RETVAL

SV *
xs_commonPrefixSearchID(txi, src)
   int txi;
   SV *src;
CODE:
   RETVAL = tx_search_id(txi, src, 0);
OUTPUT:
   RETVAL

SV *
xs_predictiveSearch(txi, src)
   int txi;
   SV *src;
CODE:
   RETVAL = tx_search(txi, src, 1);
OUTPUT:
   RETVAL

SV *
xs_predictiveSearchID(txi, src)
   int txi;
   SV *src;
CODE:
   RETVAL = tx_search_id(txi, src, 1);
OUTPUT:
   RETVAL

SV *
xs_reverseLookup(txi, id)
   int txi;
   SV *id;
CODE:
   RETVAL = tx_reverseLookup(txi, id);
OUTPUT:
   RETVAL

SV *
xs_getKeyNum(txi)
   int txi;
CODE:
   RETVAL = tx_getKeyNum(txi);
OUTPUT:
   RETVAL
