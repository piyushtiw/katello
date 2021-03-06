require 'pulp_2to3_migration_client'

module Katello
  module Pulp3
    class SwitchoverError < StandardError; end

    class MigrationSwitchover
      def initialize(*argv)
        @migration = Katello::Pulp3::Migration.new(*argv)
      end

      def content_types
        @migration.content_types_for_migration
      end

      def run
        check_already_migrated_content
        cleanup_v1_docker_tags if docker_migration?
        migrated_content_type_check
        combine_duplicate_docker_tags if docker_migration?
        migrate_pulp3_hrefs
      end

      def docker_migration?
        content_types.any? { |content_type| content_type.model_class::CONTENT_TYPE == "docker_tag" }
      end

      def migrate_pulp3_hrefs
        content_types.each do |content_type|
          content_type.model_class
              .where.not("pulp_id=migrated_pulp3_href")
              .update_all("pulp_id = migrated_pulp3_href")
        end
      end

      def check_already_migrated_content
        content_types.each do |content_type|
          if content_type.model_class.where("pulp_id=migrated_pulp3_href").any?
            Rails.logger.error("Content Switchover: #{content_type.label} seems to have already migrated content, switchover may fail.  Did you already perform the switchover?")
          end
        end
      end

      def cleanup_v1_docker_tags
        unmigrated_docker_tags = Katello::DockerTag.includes(:schema1_meta_tag, :schema2_meta_tag).where(migrated_pulp3_href: nil)
        unmigrated_docker_tags.find_in_batches(batch_size: 50_000) do |batch|
          to_delete = []

          batch.each do |unmigrated_tag|
            if unmigrated_tag.schema1_meta_tag && unmigrated_tag.schema1_meta_tag.schema2.try(:migrated_pulp3_href)
              Rails.logger.warn("Content Switchover: Deleting Docker tag #{unmigrated_tag.name} with pulp id: #{unmigrated_tag.pulp_id}")
              to_delete << unmigrated_tag.id
            end
          end
          Katello::DockerMetaTag.where(:schema1_id => to_delete).update_all(:schema1_id => nil)
          Katello::RepositoryDockerTag.where(:docker_tag_id => to_delete).delete_all
          Katello::DockerTag.where(:id => to_delete).delete_all
        end

        Katello::DockerMetaTag.cleanup_tags
      end

      def combine_duplicate_docker_tags
        to_delete = []
        Katello::DockerTag.having("count(migrated_pulp3_href) > 1").group(:migrated_pulp3_href).pluck(:migrated_pulp3_href).each do |duplicate_href|
          tags = Katello::DockerTag.where(:migrated_pulp3_href => duplicate_href).includes(:schema1_meta_tag, :schema2_meta_tag).to_a
          main_tag = tags.pop
          main_meta_v1 = main_tag.schema1_meta_tag
          main_meta_v2 = main_tag.schema2_meta_tag

          Katello::RepositoryDockerTag.where(:docker_tag_id => tags.map(&:id)).update_all(:docker_tag_id => main_tag.id)
          Katello::RepositoryDockerMetaTag.joins(:docker_meta_tag).where("#{Katello::DockerMetaTag.table_name}.schema1_id" => tags).update_all(:docker_meta_tag_id => main_meta_v1.id) if main_meta_v1
          Katello::RepositoryDockerMetaTag.joins(:docker_meta_tag).where("#{Katello::DockerMetaTag.table_name}.schema2_id" => tags).update_all(:docker_meta_tag_id => main_meta_v2.id) if main_meta_v2

          to_delete += tags.map(&:id)
        end

        to_delete.each_slice(10_000) do |group|
          Katello::RepositoryDockerTag.where(:docker_tag_id => group).delete_all
          Katello::DockerMetaTag.where(:schema1_id => group).or(Katello::DockerMetaTag.where(:schema2_id => group)).delete_all
          Katello::DockerTag.where(:id => group).delete_all
        end
      end

      def migrated_content_type_check
        content_types.each do |content_type|
          if content_type.model_class.where(migrated_pulp3_href: nil).any?
            fail SwitchoverError, "ERROR: at least one #{content_type.model_class.table_name} record has migrated_pulp3_href NULL value\n"
          end
        end
      end
    end
  end
end
