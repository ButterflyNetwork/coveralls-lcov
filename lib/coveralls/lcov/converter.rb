
module Coveralls
  module Lcov
    class Converter
      def initialize(tracefile, source_encoding = Encoding::UTF_8)
        @tracefile = tracefile
        @source_encoding = source_encoding
      end

      def service_build_url
        if ENV["BUILDKITE_JOB_ID"]
          return "https://buildkite.com/" + ENV['BUILDKITE_PROJECT_SLUG'] + "/builds/" + ENV['BUILDKITE_BUILD_NUMBER'] + "#"
        end
      end

      def service_git_branch
        if ENV["BUILDKITE_BRANCH"]
          return ENV["BUILDKITE_BRANCH"]
        end
        if ENV["TRAVIS_PULL_REQUEST"] == "false"
          return ENV["TRAVIS_BRANCH"]
        else
          return ENV["TRAVIS_PULL_REQUEST_BRANCH"]
        end
      end

      def service_job_id
        if ENV["BUILDKITE_JOB_ID"]
          return ENV["BUILDKITE_JOB_ID"]
        end
        if ENV["TRAVIS_JOB_ID"]
          return ENV["TRAVIS_JOB_ID"]
        end
      end

      def service_name
        if ENV["BUILDKITE_JOB_ID"]
          return "buildkite"
        end
        if ENV["TRAVIS_JOB_ID"]
          return "travis-ci"
        end
      end

      def service_pull_request
         if ENV["BUILDKITE_PULL_REQUEST"]
           return ENV["BUILDKITE_PULL_REQUEST"]
         end
         if ENV["TRAVIS_PULL_REQUEST"]
           return ENV["TRAVIS_PULL_REQUEST"]
         end
      end

      def convert
        source_files = []
        lcov_info = parse_tracefile
        lcov_info.each do |filename, info|
          source_files << generate_source_file(filename, info)
        end
        payload = {
          service_name: service_name,
          service_job_id: service_job_id,
          git: git_info,
          source_files: source_files,
          service_build_url: service_build_url,
          service_pull_request: service_pull_request,
        }
        payload
      end

      def parse_tracefile
        lcov_info = Hash.new {|h, k| h[k] = {} }
        source_file = nil
        File.readlines(@tracefile).each do |line|
          case line.chomp
          when /\ASF:(.+)/
            source_file = $1
          when /\ADA:(\d+),(\d+)/
            line_no = $1.to_i
            count = $2.to_i
            lcov_info[source_file][line_no] = count
          when /\Aend_of_record/
            source_file = nil
          end
        end
        lcov_info
      rescue => ex
        warn "Could not read tracefile: #{@tracefile}"
        warn "#{ex.class}: #{ex.message}"
        exit(false)
      end

      def generate_source_file(filename, info)
        source = File.open(filename, "r:#{@source_encoding}", &:read).encode("UTF-8")
        lines = source.lines
        coverage = Array.new(lines.to_a.size)
        source.lines.each_with_index do |_line, index|
          coverage[index] = info[index + 1]
        end
        top_src_dir = Dir.pwd
        {
          name: filename.sub(%r!#{top_src_dir}/!, ""),
          source: source,
          coverage: coverage,
        }
      end

      def git_info
        {
          head: {
            id: `git log -1 --format=%H`,
            committer_email: `git log -1 --format=%ce`,
            committer_name: `git log -1 --format=%cN`,
            author_email: `git log -1 --format=%ae`,
            author_name: `git log -1 --format=%aN`,
            message: `git log -1 --format=%s`,
          },
          remotes: [], # FIXME need this?
          branch: service_git_branch,
        }
      end
    end
  end
end
