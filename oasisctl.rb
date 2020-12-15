#!/usr/bin/env ruby

# This script adjusts the generated output of oasisctl:
#
# - Replace underscore with hyphen in file names
# - Fix headline levels (start at <h1>)
# - Title case for main headline
# - No all upper-case headlines ("## SEE ALSO")
# - Remove "###### Auto generated by spf13/cobra on dd-mmm-yyyy"
#
# Usage:
#
# 1. Remove the generated files from the docs target folder
#    (oasisctl-*.md but not oasisctl-getting-started.md!)
#
# 2. Create a temporary folder (oasisctl defaults to ./docs)
#
# 3. Generate the documentation
#    > oasisctl generate-docs --link-file-ext .html --replace-underscore-with -
#
# 4. Run this script
#    > ruby oasisctl.rb /path/to/generated/docs /path/to/x.x/oasis
#
# 5. This script prints navigation definition entries to stdout.
#    Update _data/x.x-oasis.yml accordingly.
#
# 6. Verify the changes and commit added and removed files
#

require 'pathname'

TITLE_CASE = {
    'apikey' => 'API Key',
    'apikeys' => 'API Keys',
    'cacertificate' => 'CA Certificate',
    'cacertificates' => 'CA Certificates',
    'ipallowlist' => 'IP Allowlist',
    'ipallowlists' => 'IP Allowlists',
    'tandc' => 'Terms & Conditions',
    'arangodb' => 'ArangoDB',
    'cpusizes' => 'CPU Sizes',
    'nodesizes' => 'Node Sizes'
}

def main()
    if ARGV.length < 2
        puts "Usage:\nruby #{File.basename(__FILE__)} <source-dir> <target-dir>"
        exit 1
    end

    inpath = Pathname.new(ARGV[0]).cleanpath
    outpath = Pathname.new(ARGV[1]).cleanpath

    raise ArgumentError, "The supplied directories are the same" if inpath == outpath

    [inpath, outpath].each { |dir|
        if not Dir.exist?(dir)
            raise IOError, "Directory does not exist: #{dir}"
        end
    }

    spaces = "    "
    prev_command = ""
    first_child = false
    Dir.glob(File.join(inpath, "oasisctl*.md"))
    .sort { |a,b|
        # Should not rely on the files being in alphabetical order
        # File extensions needs to be stripped because '-' comes before '.'
        base_a = File.basename(a, '.md')
        base_b = File.basename(b, '.md')
        base_a <=> base_b
    }
    .each { |infile|
        base = File.basename(infile)
        base = "oasisctl-options.md" if base == "oasisctl.md"
        outfile = File.join(outpath, base.gsub('_', '-'))
        rewrite_content(infile, outfile)
        title_arr = File.basename(infile, '.md').split(/[_-]/)
        title = command = "Options"
        if title_arr.length > 1
            title = title_arr[1..].map{|word|
                TITLE_CASE.fetch(word, word.capitalize)
            }.join(' ')
            command = title_arr[1]
        end

        # Output for pasting into x.x-oasis.yml navigation definition
        entry = [
            "- text: #{title}",
            "  href: #{File.basename(outfile, '.md') + '.html'}"
        ]
        if command != prev_command
            puts entry.map{ |l| spaces + l}.join("\n")
            first_child = true
        else
            puts spaces + "  children:" if first_child
            puts entry.map{ |l| spaces * 2 + l}.join("\n")
            first_child = false
        end
        prev_command = command
    }
end

def rewrite_content(infile, outfile)
    is_root = File.basename(infile) == "oasisctl.md"
    lines = File.readlines(infile)
    f = File.open(outfile, "w")
    lines.each { |line|
        if line.start_with?("###### Auto generated")
            # ignore
        # TODO: Fix inter-word capitalization of headlines?
        elsif line.start_with?("## ")
            # Capitalize first letter of each word in main headline
            f.write(line[1..].split(" ").map{|word| word.capitalize}.join(" ") + "\n")
        elsif line == "### SEE ALSO\n"
            f.write("## See also\n")
        elsif line.start_with?("### ")
            f.write(line[1..])
        # Monkey-patching frontmatter (TODO: port to oasisctl?)
        elsif is_root and line.start_with?("description: ")
            f.write("description: Command-line client tool for managing ArangoDB Oasis\n")
        elsif is_root and line.start_with?("title: ")
            f.write("title: ArangoDB Oasis Shell oasisctl\n")
        else
            # TODO: Fix capitalization of link labels?
            f.write(line
                .gsub("[oasisctl](oasisctl.html)", "[oasisctl](oasisctl-options.html)")
            )
        end
    }
    f.close()
end

main()
