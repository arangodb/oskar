#!/usr/bin/env python3

# Sample call in build documentation script
# #echo " - generating .md-files"
# python3 ${ARANGO_SOURCE}/Documentation/Scripts/generateMdFiles.py \
#        "${book_name}" \
#        "$ARANGO_SOURCE" \
#        "$ARANGO_BUILD_DOC_PRE"
#
#
#    Args:
#    book                          - book name
#    srcDir                        - arango source source
#    outDir                        - out directory
#
#
#   Info:
#
#   Documentation/Scripts/codeBlockReader.py -> creates AllComments.txt which is input to this script
#
#   TODO
#   - add path to examples
#
#

### module import
import sys
import re
import os
import json
import io
import shutil
import types
import traceback

from enum import Enum, unique
from pprint import pprint as PP
from pprint import pformat as PF


###############################################################################
# re.sub(repl,lines)
#
# repl - In this code repl is often a function that takes a match.
#        the function calculates from that match a fitting replacement
#
### set up of logging #########################################################

import logging
logger = logging.getLogger("gmdf")
logger.setLevel(logging.DEBUG)

ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)

formatter = logging.Formatter('%(name)s %(lineno)4d %(levelname)6s-> %(message)s',  datefmt='%H:%M:%S')
ch.setFormatter(formatter)
logger.addHandler(ch)

def logger_multi(level, msg, *args, **kwargs):
    [ logger.log(level, x, *args, **kwargs) for x in msg.split('\n') ]

def logger_exc(level):
    logger_multi(level, traceback.format_exc(file=sys.stdout))

### set up of logging - END ####################################################

### main #######################################################################
def main():
    if len(sys.argv) < 2:
        logger.info("usage: book arango-source output-directory swaggerJson [filter]")
        sys.exit(1)

    #add filters
    conf = Config(sys.argv[1], sys.argv[2], sys.argv[3])

    logger_multi(logging.INFO, str(conf))

    swagger=None
    with open(conf.swaggerJson, 'r', encoding='utf-8', newline=None) as f:
        swagger=json.load(f)

    block_reader = DocuBlockReader()
    blocks = block_reader.parse(conf.allComments, swagger)
    blocks.replace_code_in_blocks()

    loadProgramOptionBlocks(blocks) # FIXME

    logger.info("loaded {} / {} docu blocks".format(len(blocks.plain), len(blocks.inline)))

    # walk over .md files and replace blocks
    walk_over_book_source(conf, blocks)

    return 0
### main - END #################################################################

### helper #####################################################################
def mkdir_recursive(ipath):
    """ creates a directory of arbitrary depth"""
    path = path_abs_norm(ipath)
    os.makedirs(path, exist_ok=True)

def path_abs_norm(path):
    """ returns absolute normalized path"""
    return os.path.normpath(os.path.abspath(path))

def get_from_dict(nested, default, *access_path):
    current = nested
    for access in access_path:
        current = current.get(access, None)
        if not current:
            return default
    return current

def exectue_if_function(fun, *args, **kwargs):
    if type(fun) == types.FunctionType:
        return fun(*args, **kwargs)
    else:
        return fun

def apply_dict_re_replacement(dictionary, text):
    """
        applies a dictionary containing regexes and functions or replacement text

        Within the text the regular expressions are used to match
        substrings to be replaced. The are replaced by the provided
        replacement string/text or by the result of the function
        that is called with the re's match
    """
    for (regex, text_or_function) in dictionary:
        text = regex.sub(text_or_function, text)
    return text

def apply_dict_re_replacement_bind_params(dictionary, text, text_or_function, *args, **kwargs):
    """
        applies a dictionary containing regexes and functions or replacement text

        Within the text the regular expressions are used to match
        substrings to be replaced. The are replaced by the provided
        replacement string/text or by the result of the function
        that is called with the re's match
    """
    for (regex, text_or_function) in dictionary:
        if type(text_or_function) == types.FunctionType:
            text = regex.sub(lambda m : text_or_function(m, *args, **kwargs), text)
        else:
            text = regex.sub(text_or_function, text)
    return text
### helper - END ###############################################################

### config #####################################################################
class Config():
    def __init__(self,book, src, out):
        self.book = book
        self.src = path_abs_norm(src)
        self.out =  path_abs_norm(out)
        self.filter = None

        self.book_src = os.path.join(self.src ,"Documentation","Books", self.book)
        self.book_out = os.path.join(self.out , self.book)
        self.allComments = os.path.join(self.src, "Documentation", "Books", "allComments.txt")
        self.swaggerJson = os.path.join(self.src, "js","apps","system","_admin","aardvark","APP","api-docs.json")

    def __str__(self):
        return """
book       : {book}
src        : {src}
out        : {out}
book_src   : {book_src}
allComments: {allComments}
swaggerJson: {swaggerJson}
""".format(**(self.__dict__))
### config - END ###############################################################

## reading of DocuBlocks ######################################################
@unique
class BlockType(Enum):
    PLAIN  = 1 #auto()
    INLINE = 2 #auto()


class DocuBlocks():
    #TODO rename allComments.txt - to intermediate Docublocks
    ###### regular expressions #####################################################
    """ Structure that holds plain and inline docublocks that are found in the allComments.txt files
    """

    re_RESTHEADER = re.compile(r"@RESTHEADER\{(?P<verb>.*) (?P<route>.*),.*\}")    # DocuBlockReader.block_replace_code
    re_RESTRETURNCODE = re.compile(r"@RESTRETURNCODE\{(?P<code>.*)\}")             # DocuBlockReader.block_replace_code
    re_RESTBODYPARAM = re.compile(r"@RESTBODYPARAM|@RESTDESCRIPTION")              # DocuBlockReader.block_replace_code
    re_RESTREPLYBODY = re.compile(r"@RESTREPLYBODY")                               # DocuBlockReader.block_replace_code
    re_RESTSTRUCT = re.compile(r"@RESTSTRUCT")                                     # DocuBlockReader.block_replace_code
    re_MULTICR = re.compile(r'\n\n\n*')                                            # DocuBlockReader.block_replace_code

    # DocuBlockReader.block_replace_code
    re_block_replacement_filter = re.compile(
    r'''
    \\|                                 # the backslash...
    @RESTDESCRIPTION|                   # -> <empty>
    @HINTS|                             # -> <inject hints>
    @RESTURLPARAMETERS|                 # -> \n**Path Parameters**\n
    @RESTQUERYPARAMETERS|               # -> \n**Query Parameters**\n
    @RESTHEADERPARAMETERS|              # -> \n**Header Parameters**\n
    @RESTBODYPARAM|                     # empty now, comes with the post body -> call post body param
    @RESTRETURNCODES|                   # -> \n**Return Codes**\n
    @PARAMS|                            # -> \n**Parameters**\n
    @RESTPARAMS|                        # -> <empty>
    @RESTURLPARAMS|                     # -> <empty>
    @RESTQUERYPARAMS|                   # -> <empty>
    @PARAM|                             # -> @RESTPARAM
    @RESTURLPARAM|                      # -> @RESTPARAM
    @RESTQUERYPARAM|                    # -> @RESTPARAM
    @RESTHEADERPARAM|                   # -> @RESTPARAM
    @EXAMPLES|                          # -> \n**Examples**\n
    @RESTPARAMETERS|                    # -> <empty>
    @RESTREPLYBODY\{(?P<param>.*)\}     # -> call body function
    ''', re.X) ## re.X - be verbose
    ###### regular expressions - end ###############################################

    ###### match replace ###########################################################
    #used in block_replace_code
    dict_re_replacement_blocks = [
        ### match -> replace
        # comments -> nothing
        (re.compile(r"<!--(\s*.+\s)-->"), ""),

        # <br > newline -> newline
        (re.compile(r"<br />\n"), "\n"),

        # multi line bullet lists should become one
        (re.compile(r"\n\n-"), "\n-"),

        #HTTP API changing code
        # unwrap multi-line-briefs: (up to 3 lines supported by now ;-)
        (re.compile(r"@brief(.+)\n(.+)\n(.+)\n\n"), r"@brief\g<1> \g<2> \g<3>\n\n"),
        (re.compile(r"@brief(.+)\n(.+)\n\n"), r"@brief\g<1> \g<2>\n\n"),

        # if there is an @brief above a RESTHEADER, swap the sequence
        (re.compile(r"@brief(.+\n*)\n@RESTHEADER{([#\s\w\/\_{}-]*),([\s\w-]*)}"), r"###\g<3>\n\g<1>\n\n`\g<2>`"),

        # else simply put it into the text
        (re.compile(r"@brief(.+)"), r"\g<1>"),

        # Format error codes from errors.dat
        (re.compile(r"#####+\n"), r""),
        (re.compile(r"## (.+\n\n)## (.+\n)"), r"## \g<1>\g<2>"),
        #  (re.compile(r"- (\w+):\s*@LIT{(.+)}"), r"\n*\g<1>* - **\g<2>**:"),
        (re.compile(r"(.+),(\d+),\"(.+)\",\"(.+)\""), r'\n* <a name="\g<1>"></a>**\g<2>** - **\g<1>**<br>\n  \g<4>'),

        (re.compile(r"TODOSWAGGER.*"),r"")
        ]

    #used in block_replace_code
    dict_re_replacement_blocks_2 = [
        # parameters - extract their type and whether mandatory or not.
        (re.compile(r"@RESTPARAM{(\s*[\w\-]*)\s*,\s*([\w\_\|-]*)\s*,\s*(required|optional)}"), r"* *\g<1>* (\g<3>):"),
        (re.compile(r"@RESTALLBODYPARAM{(\s*[\w\-]*)\s*,\s*([\w\_\|-]*)\s*,\s*(required|optional)}"), r"\n**Request Body** (\g<3>)\n\n"),
        (re.compile(r"@RESTRETURNCODE{(.*)}"), r"* *\g<1>*:")
    ]
    ###### match replace ###########################################################


    def __init__(self, swagger): #GOOD
        self.plain = {}   #former 0
        self.inline = {}  #former 1
        self.swagger = swagger

    def add(self, block):
        """ adds a block found by the parser"""
        #self.block_replace_code(block)
        if block.block_type is BlockType.PLAIN:
            self.plain[block.key]=block
        elif block.block_type is BlockType.INLINE:
            self.inline[block.key]=block
        else:
            print (repr(block))
            raise ValueError("invalid block type")

    def replace_code_in_blocks(self):
        """ should happen later during add block"""
        PF(self.plain)
        for _, block in self.plain.items():
            self.block_replace_code(block)
        for _, block in self.inline.items():
            self.block_replace_code(block)


    def block_replace_code(self, block): # TODO - cleanup
        """clean up functions that needs to be run on each block"""

        verb=None
        route=None
        thisVerb = None

        foundRest = False
        # first find the header:
        headerMatch = DocuBlocks.re_RESTHEADER.search(block.content)
        if headerMatch:
            verb = headerMatch.group('verb').lower()
            route = headerMatch.group('route')

            thisVerb = get_from_dict(self.swagger, None, 'paths', route, verb)
            if not thisVerb:
                logger.error("failed to locate route in the swagger json: [" + verb + " " + route + "]" + " while analysing " + block.key)
                logger.error(block.content)
                logger.error("Did you forget to run utils/generateSwagger.sh?")
                sys.exit(0)

            foundRest = True

        for (re, replacement) in DocuBlocks.dict_re_replacement_blocks:
            block.content = re.sub(replacement, block.content)


        if foundRest:
            rest_lines_split = block.content.split('\n')
            current_line_num = 0

            rest_code = None
            found_first_RestBodyParameter = False
            maybe_rest_code_first_RestReplyBodyParam = False #false or rest_code

            while (current_line_num < len(rest_lines_split)):
                ###############################################################
                # remove all but the first RESTBODYPARAM: #####################
                if DocuBlocks.re_RESTBODYPARAM.search(rest_lines_split[current_line_num]):

                    if found_first_RestBodyParameter:
                        # remove if already found
                        rest_lines_split[current_line_num] = ''
                    else:
                        # replace RESTBODYPARAM with RESTDESCRIPTION
                        rest_lines_split[current_line_num] = '@RESTDESCRIPTION'

                    found_first_RestBodyParameter = True
                    current_line_num += 1 #advance line

                    #skip empty lines
                    #skip lines starting with @
                    #skip lines containing RESTBODYPARAM
                    line = rest_lines_split[current_line_num]
                    while (not line or line[0] != '@' or DocuBlocks.re_RESTBODYPARAM.search(line)):
                        rest_lines_split[current_line_num] = ''
                        current_line_num += 1
                        line = rest_lines_split[current_line_num]

                match = DocuBlocks.re_RESTRETURNCODE.search(rest_lines_split[current_line_num])
                if match:
                    rest_code =  match.group('code')

                ###############################################################
                # remove all but the first RESTREPLYBODY: #####################
                if DocuBlocks.re_RESTREPLYBODY.search(rest_lines_split[current_line_num]):

                    if maybe_rest_code_first_RestReplyBodyParam != rest_code:
                        # if not set or same code - paste '@RESTREPLYBODY{' + rest_code + '}\n'
                        rest_lines_split[current_line_num] = '@RESTREPLYBODY{' + rest_code + '}\n'
                    else:
                        # if we already have found the the code delete the line
                        rest_lines_split[current_line_num] = ''

                    maybe_rest_code_first_RestReplyBodyParam = rest_code
                    current_line_num += 1

                    #skip lines with more than 1 char
                    # delete rest of block
                    # if blocks are not separated by empty lines it will be very very broken
                    while len(rest_lines_split[current_line_num]) > 1:
                        rest_lines_split[current_line_num] = ''
                        current_line_num += 1

                    #try to match new code
                    match = DocuBlocks.re_RESTRETURNCODE.search(rest_lines_split[current_line_num])
                    if match:
                        rest_code =  match.group('code')

                ###############################################################
                # remove all RESTSTRUCTS - they're referenced anyways: ########
                if DocuBlocks.re_RESTSTRUCT.search(rest_lines_split[current_line_num]):
                    while (len(rest_lines_split[current_line_num]) > 1):
                        rest_lines_split[current_line_num] = ''
                        current_line_num+=1

                current_line_num += 1
                ## while - end ################################################

            block.content = "\n".join(rest_lines_split)
            ## found rest - end ###############################################

        try:
            block.content = DocuBlocks.re_block_replacement_filter.sub(lambda match : block_simple_repl(match, self.swagger, thisVerb, verb, route), block.content)
        except Exception as e:
            logger.error("While working on: [" + verb + " " + route + "]" + " while analysing " + block.key)
            logger.error(str(e))
            logger.error("Did you forget to run utils/generateSwagger.sh?")
            raise e


        for (oneRX, repl) in DocuBlocks.dict_re_replacement_blocks_2:
            block.content = oneRX.sub(repl, block.content)

        block.content = DocuBlocks.re_MULTICR.sub("\n\n", block.content)
        #logger.info(block.content)
        return block.content



class DocuBlock(): #GOOD
    """description of a single DocuBlock"""
    def __init__(self,btype):
        self.block_type = btype  # plain or inline
        self.content = ""        # textual content of the block
        self.key = None          # block key or name

class DocuBlockReader(): #GOOD
    # DocuBlockReader.handle_line_start
    re_search_start = re.compile(r" *start[0-9a-zA-Z]*\s\s*(?P<block_name>[0-9a-zA-Z_ ]*)\s*$")

    def __init__(self):
        self.blocks = None

    def parse(self, filename, swagger): #GOOD
               # file to read the blocks from
        self.blocks = DocuBlocks(swagger);    # structure that the found blocks are added to and
                                       # that is returned when the parse has finished
        """ Parses the text document that contains the DocuBlocks.

            A state machine is used here, as long as the block is
            None we search for the start of a new block. Otherwise
            we are within a block and add to the block or close it.
            When the block is closed we begin to search for a new block.
        """

        with open(filename, "r", encoding="utf-8", newline=None) as f:
            block = None
            for line in f:
                block = self.handle_line(line, block)

            if block != None:
                raise ValueError("we are inside and open block!!!")
        return self.blocks


    def handle_line(self, line, block): #GOOD
        if not block:
            block = self.handle_line_start(line)
        else:
            block = self.handle_line_follow(line, block)
        return block


    def handle_line_start(self, line): #GOOD
        if ("@startDocuBlock" in line):
            block = None

            if "@startDocuBlockInline" in line:
                block = DocuBlock(BlockType.INLINE)
            else:
                block = DocuBlock(BlockType.PLAIN)

            match = DocuBlockReader.re_search_start.search(line)
            if match:
                block.key = match.group('block_name').strip()
            else:
                logger.error("failed to read startDocuBlock: [" + line + "]")
                exit(1)
            #logger.debug("starting block with key {}".format(block.key))
            return block

        return None


    def handle_line_follow(self, line,block): #GOOD
        if '@endDocuBlock' in line:
            #logger.debug("complete: " + str(block))
            #logger.debug("complete: " + str(block.key))
            #logger.debug("complete: " + str(block.block_type))
            self.blocks.add(block)
            #logger.info("ending block with key {}".format(block.key))
            return None
        # apppend to content and do not change state
        block.content += line
        return block

## reading of DocuBlocks - END  ###############################################


## replace blocks in .md-files ################################################

def walk_over_book_source(conf, blocks): #GOOD
    """ walk over book source tree find .md-files
        skip SUMMARY.md and other files that match the filter in conf
        calculate output path and do replacements
    """

    count = 0
    skipped = 0

    #logger.info("walk on files inDirPath: " + conf.book_src)
    for root, dirs, files in os.walk(conf.book_src):
        for file in files:

            in_full_path=os.path.join(root,file)
            in_rel_path=os.path.relpath(in_full_path, conf.book_src)
            out_full_path = os.path.join(conf.book_out, in_rel_path)


            if file.endswith(".md") and not file.endswith("SUMMARY.md"):
                count += 1
                if conf.filter:
                    if conf.filter.match(in_full_path) == None:
                        skipped += 1
                        continue
                ## what are those 2 functions doing
                mkdir_recursive(os.path.dirname(out_full_path)) #create dir for output file
                walk_replace_blocks_in_file(in_full_path, out_full_path, conf, blocks)
    logger.info( "Processed %d files, skipped %d" % (count, skipped))

def walk_replace_blocks_in_file(in_full, out_full, conf, blocks):
    """ replace docublocks and images in file and write it into preprocessing directory
    """
    baseInPath = conf.book_src

    textFile = None
    with open(in_full, "r", encoding="utf-8", newline=None) as fd:
        textFile = fd.read()

    #logger.debug(textFile)
    # handle inline blocks
    matches = re.findall(r'@startDocuBlockInline\s*(\w+)', textFile)
    for match in matches:
        #logger.debug(in_full + " " + match)
        textFile = walk_replace_text_inline(textFile, in_full, match, blocks)

    # handle blocks
    matches = re.findall(r'@startDocuBlock\s*(\w+)', textFile)
    for match in matches:
        #logger.debug(in_full + " " + match)
        textFile = walk_replace_text(textFile, in_full, match, blocks)

    textFile = re.sub(g_re_images
                     ,lambda match: walk_handle_images(match.group('title')
                                                      ,match.group('link')
                                                      ,conf
                                                      ,in_full
                                                      ,out_full
                                                      )
                     ,textFile
                     )

    with open(out_full, "w", encoding="utf-8", newline="") as fd:
        fd.write(textFile)

    return 0

def walk_replace_text_inline(text, pathOfFile, searchText, blocks):
  ''' inserts docublocks into md '''
  if not searchText in blocks.inline:
      logger.error("Failed to locate the inline docublock '" + searchText + "' for replacing it into the file '" + pathOfFile + "'\n have: ")
      logger.error("%s" %(blocks.inline.keys()))
      logger.error('*' * 80)
      logger.error(text)
      logger.error("Failed to locate the inline docublock '" + searchText + "' for replacing it into the file '" + pathOfFile + "' For details scroll up!")
      exit(1)
  rePattern = r'(?s)\s*@startDocuBlockInline\s+'+ searchText +'\s.*?@endDocuBlock\s' + searchText
  # (?s) is equivalent to flags=re.DOTALL but works in Python 2.6
  match = re.search(rePattern, text)

  if (match == None):
      logger.error("failed to match with '" + rePattern + "' for " + searchText + " in file " + pathOfFile + " in: \n" + text)
      exit(1)

  subtext = match.group(0)
  if (len(re.findall('@startDocuBlock', subtext)) > 1):
      logger.error("failed to snap with '" + rePattern + "' on end docublock for " + searchText + " in " + pathOfFile + " our match is:\n" + subtext)
      exit(1)

  return re.sub(rePattern, blocks.inline[searchText].content, text)

def walk_replace_text(text, pathOfFile, searchText, blocks):
  ''' inserts docublocks into md '''
  #logger.info('7'*80)
  if not searchText in blocks.plain:
      logger.error("Failed to locate the docublock '" + searchText + "' for replacing it into the file '" +pathOfFile + "'\n have:")
      logger.error(blocks.plain.keys())
      logger.error('*' * 80)
      logger.error(text)
      logger.error("Failed to locate the docublock '" + searchText + "' for replacing it into the file '" +pathOfFile + "' For details scroll up!")
      exit(1)
  #logger.info('7'*80)
  #logger.info(blocks.plain[searchText])
  #logger.info('7'*80)
  rc= re.sub("@startDocuBlock\s+"+ searchText + "(?:\s+|$)", blocks.plain[searchText].content, text)
  return rc


g_re_images = re.compile(r".*\!\[(?P<title>[\d\s\w\/\. ()-]*)\]\((?P<link>[\d\s\w\/\.-]*)\).*")
def walk_handle_images(image_title, image_link, conf, in_full, out_full): #GOOD
    """ copy images from source to pp dir, copy book external images
        to <book>/assets and update image links accordingly.
    """
    src_image = path_abs_norm(os.path.join(os.path.dirname(in_full), image_link))
    out_image = path_abs_norm(os.path.join(os.path.dirname(out_full), image_link))

    assets = os.path.join(conf.book_out, "assets")

    #for images that are not within this book
    if os.path.commonprefix([src_image, conf.book_src]) != conf.book_src:

        ## the file will end up in out/<bookname>/assets
        # get image name
        out_image_name = os.path.basename(image_link)
        # append name to assets
        out_image = os.path.join(assets, out_image_name)

        # get path of the current document
        out_full_dir = os.path.dirname(out_full)
        # get the relative location of the assets dir to the current document
        out_image_rel_dir = os.path.relpath(assets, out_full_dir)
        # append the image name
        image_link = os.path.join(out_image_rel_dir,out_image_name)

    outdir = os.path.dirname(out_image)
    if not os.path.exists(outdir):
        mkdir_recursive(outdir)

    #logger.debug(src_image + " -> "+ out_image)
    if not os.path.exists(out_image):
        shutil.copy(src_image, out_image)

    #logger.debug("out_image:    " + out_image)
    #logger.debug("image_link:   " + image_link)
    return str('![' + image_title + '](' + image_link + ')')


g_length_definitions = len('#/definitions/')
def get_verify_reference(swagger, name, source, verb):
    """ get '$ref' key of json object and cut of '#/definitions/' from value
        check if found ref is part of swagger['definitions']
        {'$ref': '#/definitions/admin_echo_client_struct'} -> admin_echo_client_struct
    """

    ref = get_from_dict(name, None, '$ref')
    if not ref:
        logger.error("No reference in: " + name)
        sys.exit(1)

    ref = ref[g_length_definitions:] #cut off '#/definitions/'

    # extra checking
    if not ref in swagger['definitions']:
        function_name = ""
        try:
            if verb:
                function_name = swagger['paths'][route][verb]['x-filename']
            else:
                function_name = swagger['definitions'][source]['x-filename']
        except:
            pass

        logger.error(json.dumps(swagger['definitions'], indent=4, separators=(', ',': '), sort_keys=True))
        logger.error("invalid reference: " + ref + " in " + function_name)
        sys.exit(1)
        raise Exception("invalid reference: " + ref + " in " + function_name) #TODO - better exception handling

    return ref


#===============================================================================
###### block_simple_repl #######################################################
#===============================================================================

###### validation dict ########################################################
def validate_none(thisVerb):
    pass

def validate_path_parameters(thisVerb):
    # logger.info(thisVerb)
    for nParam in range(0, len(thisVerb['parameters'])):
        if thisVerb['parameters'][nParam]['in'] == 'path':
            break
    else:
        raise Exception("@RESTPATHPARAMETERS found in Swagger data without any parameter following in %s " % json.dumps(thisVerb, indent=4, separators=(', ',': '), sort_keys=True))

def validate_query_parameters(thisVerb):
    # logger.info(thisVerb)
    for nParam in range(0, len(thisVerb['parameters'])):
        if thisVerb['parameters'][nParam]['in'] == 'query':
            break
    else:
        raise Exception("@RESTQUERYPARAMETERS found in Swagger data without any parameter following in %s " % json.dumps(thisVerb, indent=4, separators=(', ',': '), sort_keys=True))

def validate_header_parameters(thisVerb):
    # logger.info(thisVerb)
    for nParam in range(0, len(thisVerb['parameters'])):
        if thisVerb['parameters'][nParam]['in'] == 'header':
            break
    else:
        raise Exception("@RESTHEADERPARAMETERS found in Swagger data without any parameter following in %s " % json.dumps(thisVerb, indent=4, separators=(', ',': '), sort_keys=True))

def validate_return_codes(thisVerb):
    # logger.info(thisVerb)
    for nParam in range(0, len(thisVerb['responses'])):
        if len(thisVerb['responses'].keys()) != 0:
            break
    else:
        raise Exception("@RESTRETURNCODES found in Swagger data without any documented returncodes %s " % json.dumps(thisVerb, indent=4, separators=(', ',': '), sort_keys=True))

#block_simple_repl
g_dict_text_function_for_validation = {
    "@HINTS"                : validate_none,
    "@RESTDESCRIPTION"      : validate_none,
    "@RESTURLPARAMETERS"    : validate_path_parameters,
    "@RESTQUERYPARAMETERS"  : validate_query_parameters,
    "@RESTHEADERPARAMETERS" : validate_header_parameters,
    "@RESTRETURNCODES"      : validate_return_codes,
    "@RESTURLPARAMS"        : validate_path_parameters,
    "@EXAMPLES"             : validate_none
}
###### validation dict - END ##################################################

###### simple dict  ########################################################
g_re_example_code_pre = re.compile(r'\*\*Example:\*\*((?:.|\n)*?)</code></pre>')
g_re_hints_for_swagger = re.compile(r'<!-- Hints Start -->.*<!-- Hints End -->', re.DOTALL)
def get_rest_description(swagger, thisVerb, verb, route, param):
    """gets rest description and removes
       **Example** ... </code></pre> before returning
    """
    #logger.debug("RESTDESCRIPTION")
    description = thisVerb.get('description', None)
    if description:
        #logger.error(description)
        # remove simplified hints, original markup is used for rendering in docs
        description = g_re_hints_for_swagger.sub(r'', description)
        return g_re_example_code_pre.sub(r'', description)
    else:
        #logger.debug("rest description empty")
        return ""

###### unwrapPostJson
g_re_lf = re.compile("\n")
g_re_double_lf = re.compile("\n\n")
def trim_and_indent(text, layer):
    text = text.rstrip('\n').lstrip('\n')
    text = g_re_double_lf.sub("\n", text)
    indent =  ' ' * (layer + 2) if layer > 0 else ""
    return g_re_lf.sub("\n" + indent, text)

g_re_trailing_br = re.compile("<br>$")
g_re_leading_br = re.compile("^<br>")
def trim_br(text):
    return g_re_leading_br.sub("", g_re_trailing_br.sub("", text.strip(' ')))

def unwrapPostJson(swagger, reference, layer):
    #TODO - create an description / talk about the format with Willi
    swaggerDataTypes = ["number", "integer", "string", "boolean", "array", "object"]
    # logger.error("xx" * layer + reference)
    unwrapped = ''

    swagger_defs_ref = swagger['definitions'][reference]

    if not 'properties' in swagger_defs_ref:
        if 'items' in swagger_defs_ref:
            if swagger_defs_ref['type'] == 'array': unwrapped += '[\n'

            subStructRef = get_verify_reference(swagger, swagger_defs_ref['items'], reference, None)
            unwrapped += unwrapPostJson(swagger, subStructRef, layer + 1)

            if swagger_defs_ref['type'] == 'array': unwrapped += ']\n'

    else: # if properties in swagger_defs_ref
        for param, thisParam in swagger_defs_ref['properties'].items():

            # is this a mandatory parameter
            required = ('required' in swagger_defs_ref and param in swagger_defs_ref['required'])
            # logger.error(thisParam)
            if '$ref' in thisParam:
                subStructRef = get_verify_reference(swagger, thisParam, reference, None)

                unwrapped += "{indent}- **{param}**:\n".format( indent = '  ' * layer, param = param)
                unwrapped += unwrapPostJson(swagger, subStructRef, layer + 1)

            elif thisParam['type'] == 'object':
                description = trim_and_indent(trim_br(thisParam['description']), layer)
                unwrapped += "{indent}- **{param}**: {description}\n".format(
                        indent = '  ' * layer,
                        param = param,
                        description = description
                )

            elif thisParam['type'] == 'array':
                unwrapped += "{indent}- **{param}**:".format( indent = '  ' * layer, param = param)
                trySubStruct = False
                line_ending="\n"

                if 'type' in thisParam['items']:
                    unwrapped += " (" + thisParam['items']['type']  + ")"
                else:
                    if len(thisParam['items']) == 0:
                        unwrapped += " (anonymous json object)"
                    else:
                        trySubStruct = True
                        line_ending=""

                description = trim_and_indent(trim_br(thisParam['description']), layer)
                unwrapped += ": {description}{ending}".format(description = description, ending = line_ending)

                if trySubStruct:
                    subStructRef = None
                    try:
                        subStructRef = get_verify_reference(swagger, thisParam['items'], reference, None)
                    except Exception as e:
                        logger.error("while analyzing: " + param)
                        logger.error(thisParam)
                        raise e
                    unwrapped += "\n" + unwrapPostJson(swagger, subStructRef, layer + 1)

            else: #if not $ref, object or array
                if thisParam['type'] not in swaggerDataTypes:
                    logger.error("while analyzing: " + param)
                    logger.error(thisParam['type'] + " is not a valid swagger datatype; supported ones: " + str(swaggerDataTypes))
                    raise Exception("invalid swagger type")

                description = trim_and_indent(trim_br(thisParam['description']), layer)
                unwrapped += "{indent}- **{param}**: {description}\n".format(
                        indent = '  ' * layer,
                        param = param,
                        description = description
                )

    return unwrapped

###### unwrapPostJson - END

def get_rest_reply_body_parameter(swagger, thisVerb, verb, route, param):
    response_body = "\n**Response Body**\n"

    schema_name = get_from_dict(thisVerb, None, 'responses', param, 'schema')
    if not schema_name:
        logger.error("failed to search " + param + " in: ")
        logger.error(json.dumps(thisVerb, indent=4, separators=(', ',': '), sort_keys=True))
        sys.exit(1)

    reference = get_verify_reference(swagger, schema_name, route, verb)
    response_body += unwrapPostJson(swagger, reference , 0)

    return response_body + "\n"

# block_simple_repl
g_dict_text_replacement = {
    "\\"                    : "\\\\",
    "@HINTS"                : "",
    "@RESTDESCRIPTION"      : get_rest_description,
    "@RESTURLPARAMETERS"    : "\n**Path Parameters**\n",
    "@RESTQUERYPARAMETERS"  : "\n**Query Parameters**\n",
    "@RESTHEADERPARAMETERS" : "\n**Header Parameters**\n",
    "@RESTRETURNCODES"      : "\n**Return Codes**\n",
    "@PARAMS"               : "\n**Parameters**\n",
    "@RESTPARAMS"           : "",
    "@RESTURLPARAMS"        : "\n**Path Parameters**\n",
    "@RESTQUERYPARAMS"      : "\n**Query Parameters**\n",
    "@RESTBODYPARAM"        : "",
    "@RESTREPLYBODY"        : get_rest_reply_body_parameter,
    "@RESTQUERYPARAM"       : "@RESTPARAM",
    "@RESTURLPARAM"         : "@RESTPARAM",
    "@PARAM"                : "@RESTPARAM",
    "@RESTHEADERPARAM"      : "@RESTPARAM",
    "@EXAMPLES"             : "\n**Examples**\n",
    "@RESTPARAMETERS"       : ""
}
###### simple dict - END ########################################################

def block_simple_repl(match, swagger, thisVerb, verb, route):
    match_0 = match.group(0)
    #logger.info('xxxxx [%s]' % m)
    #logger_multi(logging.ERROR, 'xxxxx [%s]' % thisVerb)

    validation_function = g_dict_text_function_for_validation.get(match_0, None)
    if validation_function:
        validation_function(thisVerb)


    rest_replacement = g_dict_text_replacement.get(match_0, None)
    if rest_replacement:
        return exectue_if_function(rest_replacement, swagger, thisVerb, verb, route, None)
    else:
        pos = match_0.find('{')
        ## @EXAMPLE: RESTREPLYBODY{200} -> new_match = @RESTREPLYBODY
        ##                              -> param = 200
        if pos > 0:
            new_match = match_0[:pos]
            param = match_0[pos + 1:].rstrip(' }')

            new_rest_replacement = g_dict_text_replacement.get(new_match, None)
            if new_rest_replacement == None:
                raise Exception("failed to find regex while searching for: " + new_match + " extracted from: " + m)
            else:
                return exectue_if_function(new_rest_replacement, swagger, thisVerb, verb, route, param)

#===============================================================================
###### block_simple_repl - END #################################################
#===============================================================================


## replace blocks in .md-files - END ##########################################

def loadProgramOptionBlocks(blocks):
    from itertools import groupby, chain
    from cgi import escape
    from glob import glob

    # Allows to test if a group will be empty with obsolete options ignored
    def peekIterator(iterable, condition):
        try:
            while True:
                first = next(iterable)
                if condition(first):
                    break
        except StopIteration:
            return None
        return first, chain([first], iterable)

    # Give options a the section name 'global' if they don't have one
    def groupBySection(elem):
        return elem[1]["section"] or 'global'

    # Empty section string means global option, which should appear first
    def sortBySection(elem):
        section = elem[1]["section"]
        if section:
            return (1, section)
        return (0, u'global')

    # Format possible values as unordered list
    def formatList(arr, text=''):
        formatItem = lambda elem: '<li><code>{}</code></li>'.format(elem)
        return '{}<ul>{}</ul>\n'.format(text, '\n'.join(map(formatItem, arr)))

    for programOptionsDump in glob(os.path.normpath('../Examples/*.json')):

        program = os.path.splitext(os.path.basename(programOptionsDump))[0]
        output = []

        # Load program options dump and convert to Python object
        with io.open(programOptionsDump, 'r', encoding='utf-8', newline=None) as fp:
            try:
                optionsRaw = json.load(fp)
            except ValueError as err:
                # invalid JSON
                logger.error("Failed to parse program options json: '" + programOptionsDump + "' - to be used as: '" + program + "' - " + err.message)
                raise err

        # Group and sort by section name, global section first
        for groupName, group in groupby(
                sorted(optionsRaw.items(), key=sortBySection),
                key=groupBySection):

            # Use some trickery to skip obsolete options without consuming items from iterator
            groupPeek = peekIterator(group, lambda elem: elem[1].setdefault("obsolete", False) is False)
            if groupPeek is None:
                # Skip empty section to avoid useless headline (all options are obsolete)
                continue

            # Output table header with column labels (one table per section)
            output.append('\n<h2>{} Options</h2>'.format(groupName.title()))
            if program in ['arangod']:
                output.append('\nAlso see <a href="{0}.html">{0} details</a>.'.format(groupName.title()))
            output.append('\n<table class="program-options"><thead><tr>')
            output.append('<th>{}</th><th>{}</th><th>{}</th>'.format('Name', 'Type', 'Description'))
            output.append('</tr></thead><tbody>')

            # Sort options by name and output table rows
            for optionName, option in sorted(groupPeek[1], key=lambda elem: elem[0]):

                # Skip options marked as obsolete, eventhough they are not dumped at the moment
                if option.setdefault("obsolete", False):
                    continue

                # Recover JSON syntax, because the Python representation uses [u'this format']
                default = json.dumps(option["default"])

                # Whether the default value depends on the target host capabilities or configuration
                dynamic = option.setdefault("dynamic", False)

                if dynamic:
                    defaultDynamic = '<br/>Default: <em>dynamic</em> (e.g. <code>{}</code>)'.format(default)
                else:
                    defaultDynamic = '<br/>Default: <code>{}</code>'.format(default)

                # Parse and re-format the optional field for possible values
                # (not fully safe, but ', ' is unlikely to occur in strings)
                try:
                    optionList = option["values"].partition('Possible values: ')[2].split(', ')
                    values = formatList(optionList, '<br/>Possible values:\n')
                except KeyError:
                    values = ''

                # Expected data type for argument
                valueType = option["type"]

                # Enterprise Edition has EE only options marked
                enterprise = ""
                if option.setdefault("enterpriseOnly", False):
                    enterprise = "<em>Enterprise Edition only</em><br/>"

                # Beside option there are also flag-like commands (like --version)
                isCommand = ""
                category = option.setdefault("category", "option")
                if category == "command":
                    isCommand = '<br/>This is a command, no value needs to be specified. The process terminates after executing the command.'

                # Some Boolean options can be used like flags (also true for commands)
                isFlag = ""
                requiresValue = option.setdefault("requiresValue", True)
                if not requiresValue and category != "command":
                    isFlag = '<br/>This option can be specified without value to enable it.'

                # Versions since the option is available or when it was marked as deprecated
                versionInfo = ""
                introducedIn = option.setdefault("introducedIn", None)
                deprecatedIn = option.setdefault("deprecatedIn", None)
                if introducedIn:
                    versionInfo += '<br/><small>Introduced in: {}</small>'.format(", ".join(introducedIn))
                if deprecatedIn:
                    versionInfo += '<br/><small>Deprecated in: {}</small>'.format(", ".join(deprecatedIn))

                # Upper-case first letter, period at the end, HTML entities
                description = option["description"].strip()
                description = description[0].upper() + description[1:]
                if description[-1] != '.':
                    description += '.'
                description = escape(description)

                # Description, default value and possible values separated by line breaks
                descriptionCombined = '\n'.join([enterprise, description, isFlag, isCommand, defaultDynamic, values, versionInfo])

                output.append('<tr><td><code>{}</code></td><td>{}</td><td>{}</td></tr>'.format(optionName, valueType, descriptionCombined))

            output.append('</tbody></table>')

        # Join output and register as docublock (like 'program_options_arangosh')
        block = DocuBlock(BlockType.PLAIN)
        block.key = 'program_options_' + program.lower()
        block.content = '\n'.join(output) + '\n\n'
        blocks.add(block)

#################################################################################

if __name__ == '__main__':
    sys.exit(main())
