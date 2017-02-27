lebyr: Automatic acquisition of Japanese unknown morphemes from text
=======

  (c) MURAWAKI Yugo, 2007-2016


What's this?
-----------

日本語テキストから未知語を獲得するプログラムです。
テキストを逐次的に読みながら、辞書にない形態素 (未知語) を見つけます。
そうした用例を溜め込み、それらを比較することによって曖昧性を解消し、辞書に追加します。

このプログラムは形態素解析器 JUMAN、構文格解析器 KNP を利用しています。
獲得時には JUMAN の辞書を動的に書き換えます。

また、最初の獲得時点では、普通名詞、サ変名詞、ナ形容詞、ナノ形容詞の区別が曖昧なので、獲得後も出現例を調べ続け、充分な用例が溜まった時点でこれらの識別を行います。

獲得された形態素のうち、名詞については細分類 (固有名詞の場合は (人名、組織名、地名) 等、普通名詞に場合は (人、組織、場所、動物) 等) を改めて行います。
ただし、この処理は本体に含まれていますが、統合されてはいません。また、精度は低く、誤りが目立ちます。

獲得された形態素が別の形態素と異表記の関係である場合 (例えば、獲得語「カサつく」は既知語「かさつく」の異表記」) の認識も行います。
ただし、単純な表記の類似だけを見ると、「アワー」と「アワ」のように実際には無関係なペアも候補に挙がります。
そこで、ペアの分布類似度 (テキスト中での振る舞いの類似性) を見て、最終的に異表記関係を認識しています。
ここで必要な分布類似度計算モジュールは本パッケージには含まれていません。
また、その性質上、分布類似度データベースの構築には大規模なテキストが必要になります。

名詞類は、単形態素と複合名詞の区別が難しいという問題があります。
現在はヒューリスティックな処理が行われています。
これとは別に統計的手法により分割する研究も行いましたが、本パッケージには統合されていません。



How to cite
-----------

未知語獲得の主要処理:

 * Yugo Murawaki and Sadao Kurohashi. 2008. Online Acquisition of Japanese Unknown Morphemes using Morphological Constraints. In Proc. of EMNLP.

ひらがな未知語の検出:

 * Yugo Murawaki and Sadao Kurohashi. 2010. Online Japanese Unknown Morpheme Detection using Orthographic Variation. In Proc. of LREC.

名詞の細分類:

 * Yugo Murawaki and Sadao Kurohashi. 2010. Semantic Classification of Automatically Acquired Nouns using Lexico-Syntactic Clues. In Proc. of COLING.

異表記関係の認識:

 * 柴田 知秀, 村脇 有吾, 黒橋 禎夫, 河原 大輔. 2012. 実テキスト解析をささえる語彙知識の自動獲得. 言語処理学会 第18回年次大会.


Subdirectories
-----------

下位ディレクトリは以下の構成です。各ディレクトリの INSTRUCTIONS ファイルに実行方法のメモがあります。

  * crawl/
    日々のクロールデータからの語彙獲得
  * lib/
    雑多な Perl モジュール群
  * noun/
    名詞の細分類 (2段階目の獲得)
  * server/
    Tweet からの語彙獲得 (休止中・Twitter の仕様変更により修正が必要)
  * suffix/
    語彙獲得に必要な suffix の構築
  * test/
    雑多なスクリプト群
  * tx/
    tx を Perl から呼び出すためのインターフェース
  * unknown/
    テキストからの語彙獲得 (1段回目)

  * prefs
    プログラムの設定ファイル
  * update.sh
    JUMAN の辞書を更新するためのスクリプト



Requirements
-----------

  * JUMAN, KNP: 日本語解析ツール
    * JUMAN はソースコードも必要
    * juman-perl, knp-perl を含む
  * tinycdb
  * tx by Okanohara-san
  * Perl5
  * 各種 CPAN モジュール
    * CDB_File
    * Parse::Yapp
    * Unicode::Japanese
    * Class::Accessor::Fast
    * Class::Data::Inheritable
    * IO::Scalar

Setup
-----------

  1. lebyr を入手

     git clone https://github.com/murawaki/lebyr.git

  2. lebyr 付属の tx-perl をインストール

     cd $LEBYR-ROOT-DIR/tx

     perl Makefile.PL  # 修正が必要かも

     make

     make install

  3. 各種モデルのダウンロード

     cd $LEBYR-ROOT-DIR

     wget http://lotus.kuee.kyoto-u.ac.jp/~murawaki/lebyr/lebyr-model-20160407.tar.bz2

     tar jxvf lebyr-model-20160407.tar.bz2

  4. (元からある) JUMAN 辞書を lebyr 向けにコンパイル

     cd $LEBYR-ROOT-DIR

     mkdir -p data/dic

     perl -Ilib unknown/makedic.pl --inputdir $JUMAN_SOURCE_PATH/dic --outputdir data/dic

     mkdir -p data/autodic

     perl -Ilib unknown/makedic.pl --inputdir $JUMAN_SOURCE_PATH/autodic --outputdir data/autodic

     mkdir -p data/wikipediadic

     perl -Ilib unknown/makedic.pl --inputdir $JUMAN_SOURCE_PATH/wikipediadic --outputdir data/wikipediadic

  5. prefs を編集して辞書、モデル等のパスを修正

     * 本ツールは juman.rcfile に指定された jumanrc を元に、獲得語彙を格納する辞書を指定する jumanrc を生成します

       * この rcfile が指定する「辞書ファイル」は 4. でコンパイルした辞書と一致していなければなりません

  6. 環境変数 JUMAN_PREFIX を設定 (JUMAN バイナリの prefix)


Give it a try
-----------

  cd $LEBYR-ROOT-DIR

  perl -Ilib unknown/sequential.pl --conf=prefs --monitor --dicdir=/tmp/adic --raw test/sample.txt --debug

  /tmp/adic/output.dic にラ行動詞「ファボる」が登録されていれば成功です。
