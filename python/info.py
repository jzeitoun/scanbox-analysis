from sbxmap import sbxmap

import sys
import pprint

def parse_meta(filename):
    '''
    Simple script for displaying sbx metadata.
    '''
    sbx = sbxmap(filename)
    pp = pprint.PrettyPrinter(indent=2)
    pp.pprint(sbx.info)

def main():
    parse_meta(sys.argv[1])

if __name__ == '__main__':
    main()

