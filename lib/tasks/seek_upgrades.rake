require 'rubygems'
require 'rake'
require 'active_record/fixtures'
require 'uuidtools'
require 'fastercsv'

namespace :seek do
  
  #these are the tasks required for this version upgrade
  task :upgrade_version_tasks=>[
            :environment,
            :relink_strains,
            :repopulate_auth_lookup_tables,
            :rebuild_default_subscriptions,
            :reindex_things
  ]

  desc "Disassociates creators and refreshes the list of publication authors from the doi/pubmed for all publications"
  task :reset_publication_authors=>[:environment] do
    disable_authorization_checks do
      Publication.all.each do |publication|
        publication.creators.clear #get rid of author links
        publication.publication_authors.clear

        #Query pubmed article to fetch authors
        result = nil
        pubmed_id = publication.pubmed_id
        doi = publication.doi
        if pubmed_id
          query = PubmedQuery.new("seek",Seek::Config.pubmed_api_email)
          result = query.fetch(pubmed_id)
        elsif doi
          query = DoiQuery.new(Seek::Config.crossref_api_email)
          result = query.fetch(doi)
        end
        unless result.nil?
          result.authors.each_with_index do |author, index|
            pa = PublicationAuthor.new()
            pa.publication = publication
            pa.first_name = author.first_name
            pa.last_name = author.last_name
            pa.author_index = index
            pa.save
          end
        end
      end
    end
  end

  desc "read publication authors from spreadsheet"
  task :read_publication_authors => [:environment] do
    FasterCSV.foreach("publication_authors.csv") do |row|
      next if row[0] == 'publication name'
      publication = Publication.find(row[1].match(/\d*$/).to_s.to_i)
      pa = publication.publication_authors.detect {|pa| pa.first_name == row[2] and pa.last_name == row[3]}
      if pa.nil?
        raise "Could not find #{row[2]} #{row[3]} for #{publication.title} id: #{publication.id}"
      end
      unless row[7] == "NO LINK"
        if !row[9].blank?
          person = Person.find(row[9].match(/\d*$/).to_s.to_i)
          raise "#{row[9]} did not resolve to a valid person" unless person
        elsif !row[6].blank?
          person = Person.find(row[6].match(/\d*$/).to_s.to_i) if !row[6].blank?
          raise "#{row[9]} did not resolve to a valid person" unless person
        end

        if person
          pa.person = person
          disable_authorization_checks {pa.save!}
        end
      end
    end
  end

  desc "guess publication authors and dump to a csv"
  task :guess_publication_authors_to_csv => [:environment] do
    FasterCSV.open("publication_authors.csv", "w") do |csv|
      Publication.all.each do |publication|
        publication.publication_authors.each do |author|
	  projects = publication.projects.empty? ? (publication.contributor.try(:person).try(:projects) || []) : publication.projects
          matches = []
          #Get author by last name
          last_name_matches = Person.find_all_by_last_name(author.last_name)
          matches = last_name_matches
          #If no results, try searching by normalised name, taken from grouped_pagination.rb
          if matches.size < 1
            text = author.last_name
            #handle the characters that can't be handled through normalization
            %w[ØO].each do |s|
              text.gsub!(/[#{s[0..-2]}]/, s[-1..-1])
            end

            codepoints = text.mb_chars.normalize(:d).split(//u)
            ascii=codepoints.map(&:to_s).reject { |e| e.length > 1 }.join

            last_name_matches = Person.find_all_by_last_name(ascii)
            matches = last_name_matches
          end

          #If more than one result, filter by project
          if matches.size > 1
            project_matches = matches.select { |p| p.member_of?(projects) }
            if project_matches.size >= 1 #use this result unless it resulted in no matches
              matches = project_matches
            end
          end

          #If more than one result, filter by first initial
          if matches.size > 1
            first_and_last_name_matches = matches.select { |p| p.first_name.at(0).upcase == author.first_name.at(0).upcase }
            if first_and_last_name_matches.size >= 1 #use this result unless it resulted in no matches
              matches = first_and_last_name_matches
            end
          end

          #Take the first match as the guess
          if match = matches.first
            csv << [publication.title, "seek.virtual-liver.de/publications/#{publication.id}", author.first_name, author.last_name, match.first_name, match.last_name, "seek.virtual-liver.de/people/#{match.id}"]
          else
            csv << [publication.title, "seek.virtual-liver.de/publications/#{publication.id}", author.first_name, author.last_name, nil, nil, nil]
          end
        end
      end
    end
  end

  desc("upgrades SEEK from the last released version to the latest released version")
  task(:upgrade=>[:environment,"db:migrate","tmp:clear","tmp:assets:clear"]) do
    
    solr=Seek::Config.solr_enabled

    Seek::Config.solr_enabled=false

    Rake::Task["seek:upgrade_version_tasks"].invoke

    Seek::Config.solr_enabled = solr

    puts "Upgrade completed successfully"
  end


  desc "removes the older duplicate create activity logs that were added for a short period due to a bug (this only affects versions between stable releases)"
  task(:remove_duplicate_activity_creates=>:environment) do
    ActivityLog.remove_duplicate_creates
  end

  task :reindex_things => :environment do
    #reindex_all task doesn't seem to work as part of the upgrade, because it doesn't successfully discover searchable types (possibly due to classes being in memory before the migration)
    ReindexingJob.add_items_to_queue DataFile.all, 5.seconds.from_now,2
    ReindexingJob.add_items_to_queue Model.all, 5.seconds.from_now,2
    ReindexingJob.add_items_to_queue Sop.all, 5.seconds.from_now,2
    ReindexingJob.add_items_to_queue Publication.all, 5.seconds.from_now,2
    ReindexingJob.add_items_to_queue Presentation.all, 5.seconds.from_now,2

    ReindexingJob.add_items_to_queue Assay.all, 5.seconds.from_now,2
    ReindexingJob.add_items_to_queue Study.all, 5.seconds.from_now,2
    ReindexingJob.add_items_to_queue Investigation.all, 5.seconds.from_now,2

    ReindexingJob.add_items_to_queue Person.all, 5.seconds.from_now,2
    ReindexingJob.add_items_to_queue Project.all, 5.seconds.from_now,2
    ReindexingJob.add_items_to_queue Specimen.all, 5.seconds.from_now,2
    ReindexingJob.add_items_to_queue Sample.all, 5.seconds.from_now,2
  end


  task :relink_strains => :environment do
    disable_authorization_checks do
      Strain.all.select{|s| s.organism.nil?}.each do |s|
        s.destroy
      end
    end

    strains = YAML.load_file(File.join(Rails.root,"config","default_data","strains.yml"))
    disable_authorization_checks do
      strains.keys.each do |key|
        strain = strains[key]
        title = strain["title"]
        organism = strain["organism"]
        if (Strain.find_by_title(title).nil?)
          o = Organism.find_by_title(organism)
          if (!o.nil?)
            s = Strain.new :title=>title, :organism=>o
            policy = Policy.public_policy
            policy.save
            s.policy_id = policy.id
            s.save!
          end
        end
      end
    end
  end

  #reverts to use pre-2.3.4 id generation to keep generated ID's consistent
  def revert_fixtures_identify
    def Fixtures.identify(label)
      label.to_s.hash.abs
    end
  end

  desc "Resubscribe all existing people by their projects with weekly frequency"
  task :rebuild_default_subscriptions => :environment do
    puts "Rebuilding subscription details - this can take some time so please be patient!"
    ProjectSubscription.delete_all
    Subscription.delete_all
    Person.all(:order=>:id).each do |p|
      p.set_default_subscriptions
      disable_authorization_checks { p.save(false) }
      puts "\tcompleted for person id:#{p.id}"
    end
    puts "Finished rebuilding subscription details"
  end
end
