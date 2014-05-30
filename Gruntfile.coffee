module.exports = (grunt) ->

  # Configuration
  # -------------

  pkg = grunt.file.readJSON 'package.json'

  grunt.initConfig {

    pkg

    clean:
      build: 'bin/*'

      dist:      'dist/*'
      distAfter: 'dist/temp/'

      docs: 'docs/*'

    compress:
      dist:
        files: [
          expand: true
          cwd:    'dist/temp/'
          src:    '**/*'
        ]
        options:
          archive: 'dist/Template.zip'
          level:   9
          pretty:  yes

    copy:
      build:
        expand: yes
        cwd:    'src/'
        src:    ['**', '!lib/*']
        dest:   'bin/'

      dist:
        expand: yes
        cwd:    'bin/'
        src:    ['**', '!lib/*', '!vendor/**/*.js', 'vendor/**/*.min.js']
        dest:   'dist/temp/'

    coffee:
      build:
        expand: yes
        cwd:    'src/'
        src:    '*.coffee'
        dest:   'bin/'
        ext:    '.js'

    docco:
      dist:
        src: 'src/lib/**/*.coffee'
        options:
          output: 'docs/'

    'json-minify':
      dist:
        files: 'dist/temp/**/*.json'

    uglify:
      distLib:
        files: [
          expand: yes
          cwd:    'bin/lib/'
          src:    '*.js'
          dest:   'dist/temp/lib/'
        ]
        options:
          banner: """
            /*! Template v<%= pkg.version %> | (c) <%= grunt.template.today("yyyy") %> <%= pkg.author.name %> | <%= pkg.licenses[0].url %> */

          """

      distVendor:
        files: [
          expand: yes
          cwd:    'bin/vendor/'
          src:    ['**/*.js', '!**/*.min.js']
          dest:   'dist/temp/vendor/'
        ]
        options:
          preserveComments: 'some'

  }

  # Tasks
  # -----

  for dependency of pkg.devDependencies when ~dependency.indexOf 'grunt-'
    grunt.loadNpmTasks dependency

  grunt.registerTask 'build', [
    'clean:build'
    'coffee'
    'copy:build'
  ]

  grunt.registerTask 'dist', [
    'clean:dist'
    'copy:dist'
    'json-minify'
    'uglify'
    'compress'
    'clean:distAfter'
  ]

  grunt.registerTask 'docs', [
    'clean:docs'
    'docco'
  ]

  grunt.registerTask 'default', ['build']
