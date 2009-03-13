class SopsController < ApplicationController
  before_filter :login_required, :except => [ :index, :show, :download ]
  
  before_filter :find_sops, :only => [ :index ]
  before_filter :find_sop_auth, :except => [ :index, :new, :create ]
  
  before_filter :set_parameters_for_sharing_form, :only => [ :new, :edit ]
  
  
  # GET /sops
  def index
    respond_to do |format|
      format.html # index.html.erb
    end
  end

  # GET /sops/1
  def show
    # store timestamp of the previous last usage
    @last_used_before_now = @sop.last_used_at
    
    # update timestamp in the current SOP record 
    # (this will also trigger timestamp update in the corresponding Asset)
    @sop.last_used_at = Time.now
    @sop.save_without_timestamping
    
    respond_to do |format|
      format.html # show.html.erb
    end
  end
  
  # GET /sops/1;download
  def download
    # update timestamp in the current SOP record 
    # (this will also trigger timestamp update in the corresponding Asset)
    @sop.last_used_at = Time.now
    @sop.save_without_timestamping
    
    send_data @sop.content_blob.data, :filename => @sop.original_filename, :content_type => @sop.content_type, :disposition => 'attachment'
  end

  # GET /sops/new
  def new
    respond_to do |format|
      if Authorization.is_member?(current_user.person_id, nil, nil)
        format.html # new.html.erb
      else
        flash[:error] = "You are not authorized to upload new SOPs. Only members of known projects, institutions or work groups are allowed to create new content."
        format.html { redirect_to sops_path }
      end
    end
  end

  # GET /sops/1/edit
  def edit
  
  end

  # POST /sops
  def create
    if (params[:sop][:data]).blank?
      respond_to do |format|
        flash.now[:error] = "Please select a file to upload."
        format.html { 
          set_parameters_for_sharing_form()
          render :action => "new" 
        }
      end
    elsif (params[:sop][:data]).size == 0
      respond_to do |format|
        flash.now[:error] = "The file that you have selected is empty. Please check your selection and try again!"
        format.html { 
          set_parameters_for_sharing_form()
          render :action => "new" 
        }
      end
    else
      # create new SOP and content blob - non-empty file was selected

      # prepare some extra metadata to store in SOP instance
      params[:sop][:contributor_type] = "User"
      params[:sop][:contributor_id] = current_user.id
      
      # store properties and contents of the file temporarily and remove the latter from params[],
      # so that when saving main object params[] wouldn't contain the binary data anymore
      params[:sop][:content_type] = (params[:sop][:data]).content_type
      params[:sop][:original_filename] = (params[:sop][:data]).original_filename
      data = params[:sop][:data].read
      params[:sop].delete('data')
      
      # store source and quality of the new SOP (this will be kept in the corresponding asset object eventually)
      # TODO set these values to something more meaningful, if required for SOPs
      params[:sop][:source_type] = "upload"
      params[:sop][:source_id] = nil
      params[:sop][:quality] = nil
      
      
      @sop = Sop.new(params[:sop])
      @sop.content_blob = ContentBlob.new(:data => data)

      respond_to do |format|
        if @sop.save
          # the SOP was saved successfully, now need to apply policy / permissions settings to it
          policy_err_msg = Policy.create_or_update_policy(@sop, current_user, params)
          
          # update attributions
          Relationship.create_or_update_attributions(@sop, params[:attributions])
          
          if policy_err_msg.blank?
            flash[:notice] = 'SOP was successfully uploaded and saved.'
            format.html { redirect_to sop_path(@sop) }
          else
            flash[:notice] = "SOP was successfully created. However some problems occurred, please see these below.</br></br><span style='color: red;'>" + policy_err_msg + "</span>"
            format.html { redirect_to :controller => 'sops', :id => @sop, :action => "edit" }
          end
        else
          format.html { 
            set_parameters_for_sharing_form()
            render :action => "new" 
          }
        end
      end
    end
    
  end


  # PUT /sops/1
  def update
    # remove protected columns (including a "link" to content blob - actual data cannot be updated!)
    if params[:sop]
      [:contributor_id, :contributor_type, :original_filename, :content_type, :content_blob_id, :created_at, :updated_at, :last_used_at].each do |column_name|
        params[:sop].delete(column_name)
      end
    
      # update 'last_used_at' timestamp on the SOP
      params[:sop][:last_used_at] = Time.now
      
      # update 'contributor' of the SOP to current user (this under no circumstances should update
      # 'contributor' of the corresponding Asset: 'contributor' of the Asset is the "owner" of this
      # SOP, e.g. the original uploader who has unique rights to manage this SOP; 'contributor' of the
      # SOP on the other hand is merely the last user to edit it)
      params[:sop][:contributor_type] = current_user.class.name
      params[:sop][:contributor_id] = current_user.id
    end
    
    respond_to do |format|
      if @sop.update_attributes(params[:sop])
        # the SOP was updated successfully, now need to apply updated policy / permissions settings to it
        policy_err_msg = Policy.create_or_update_policy(@sop, current_user, params)
        
        # update attributions
        Relationship.create_or_update_attributions(@sop, params[:attributions])
        
        if policy_err_msg.blank?
            flash[:notice] = 'SOP metadata was successfully updated.'
            format.html { redirect_to sop_path(@sop) }
          else
            flash[:notice] = "SOP metadata was successfully updated. However some problems occurred, please see these below.</br></br><span style='color: red;'>" + policy_err_msg + "</span>"
            format.html { redirect_to :controller => 'sops', :id => @sop, :action => "edit" }
          end
      else
        format.html { 
          set_parameters_for_sharing_form()
          render :action => "edit" 
        }
      end
    end
  end

  # DELETE /sops/1
  def destroy
    @sop.destroy

    respond_to do |format|
      format.html { redirect_to(sops_url) }
    end
  end
  
  
  protected
  
  def find_sops
    found = Sop.find(:all, 
                     :order => "title",
                     :page => { :size => default_items_per_page, :current => params[:page] })
    
    # this is only to make sure that actual binary data isn't sent if download is not
    # allowed - this is to increase security & speed of page rendering;
    # further authorization will be done for each item when collection is rendered
    found.each do |sop|
      sop.content_blob.data = nil unless Authorization.is_authorized?("download", nil, sop, current_user)
    end
    
    @sops = found
  end
  
  
  def find_sop_auth
    begin
      sop = Sop.find(params[:id])
      
      if Authorization.is_authorized?(action_name, nil, sop, current_user)
        @sop = sop
      else
        respond_to do |format|
          flash[:error] = "You are not authorized to perform this action"
          format.html { redirect_to sops_path }
        end
        return false
      end
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        flash[:error] = "Couldn't find the SOP or you are not authorized to view it"
        format.html { redirect_to sops_path }
      end
      return false
    end
  end
  
  
  def set_parameters_for_sharing_form
    policy = nil
    policy_type = ""
    
    # obtain a policy to use
    if defined?(@sop) && @sop.asset
      if (policy = @sop.asset.policy)
        # SOP exists and has a policy associated with it - normal case
        policy_type = "asset"
      elsif @sop.asset.project && (policy = @sop.asset.project.default_policy)
        # SOP exists, but policy not attached - try to use project default policy, if exists
        policy_type = "project"
      end
    end
    
    unless policy
      # several scenarios could lead to this point:
      # 1) this is a "new" action - no SOP exists yet; use default policy:
      #    - if current user is associated with only one project - use that project's default policy;
      #    - if current user is associated with many projects - use system default one;
      # 2) this is "edit" action - SOP exists, but policy wasn't attached to it;
      #    (also, SOP wasn't attached to a project or that project didn't have a default policy) --
      #    hence, try to obtain a default policy for the contributor (i.e. owner of the SOP) OR system default 
      projects = current_user.person.projects
      if projects.length == 1 && (proj_default = projects[0].default_policy)
        policy = proj_default
        policy_type = "project"
      else
        policy = Policy.default(current_user)
        policy_type = "system"
      end
    end
    
    # set the parameters
    # ..from policy
    @policy = policy
    @policy_type = policy_type
    @sharing_mode = policy.sharing_scope
    @access_mode = policy.access_type
    @use_custom_sharing = (policy.use_custom_sharing == true || policy.use_custom_sharing == 1)
    @use_whitelist = (policy.use_whitelist == true || policy.use_whitelist == 1)
    @use_blacklist = (policy.use_blacklist == true || policy.use_blacklist == 1)
    
    # ..other
    @resource_type = "SOP"
    @favourite_groups = current_user.favourite_groups
    
    @all_people_as_json = Person.get_all_as_json
    # TODO
    # find all projects and their IDs
    
  end
  
end
