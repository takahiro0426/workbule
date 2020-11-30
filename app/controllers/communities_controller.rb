class CommunitiesController < ApplicationController
	before_action :authenticate_user!
	def show
		@community = Community.find(params[:id])
		@subscribed_user = @community.user_communities.includes(:user)
		@members = User.where(id: @subscribed_user.pluck(:user_id))
		@posts = @community.community_posts.order(created_at: :desc).page(params[:page]).per(100).search(params[:search])
		@new_post = CommunityPost.new
		if params[:post_community_id]
			@select_post = CommunityPost.find(params[:post_community_id])
			@comments = @select_post.post_comments.limit(8).order(created_at: :desc)
			@new_comment = PostComment.new
		end
	end

	def new
		@new_key = Community.create_new_community_key
		@new_community = Community.new
	end

	def create
		if params[:community]
			community = Community.new(community_params)
	    if community.invalid?
	    	flash.now[:danger] = Community.create_error_message(community)
	      @new_community = Community.new(community_params)
	      @new_key = community.community_key
	      render :new
    	else
    		community.save
				# コミュニティ-を作ると同時に参加
				UserCommunity.create(user_id: current_user.id, community_id: community.id, is_role: 3)
				redirect_to community_path(community), success: "【#{community.community_name}】を作成しました！"
			end
		elsif params[:community_post]
			post = CommunityPost.new(community_post_params)
			if post.invalid?
				@community = Community.find(params[:community_post][:community_id])
				@subscribed_user = @community.user_communities.includes(:user)
				@members = User.where(id: @subscribed_user.pluck(:user_id))
				@posts = @community.community_posts.order(created_at: :desc).page(params[:page]).per(100).search(params[:search])
				@new_post = CommunityPost.new(community_post_params)
				flash.now[:danger] = CommunityPost.create_error_message(post)
				render :show
			else
				post.save
				if post.image
					image_tags = Vision.get_image_data(post.image)
					image_tags.each do |tag|
						post.image_tags.create(tag: tag)
					end
				end
				redirect_to community_path(post.community_id), success: "投稿しました！"
			end
		else
			comment = PostComment.create(post_comment_params)
			if comment.invalid?
				redirect_to community_path(params[:post_comment][:community_id], post_community_id: comment.community_post_id), danger: "コメントは1〜30文字以内です"
			else
				comment.save
				# 第一はcommunityの特定、第二引数は@select_postへ代入し、commentしたpost_communityを表示する処理で用います
				redirect_to community_path(params[:post_comment][:community_id], post_community_id: comment.community_post_id)
			end
		end
	end

	def edit
	end

	private

	def community_params
		params.require(:community).permit(:community_name, :community_key, :community_info)
	end

	def community_post_params
		params.require(:community_post).permit(:user_id, :community_id, :image, :tag_id, :title, :caption).merge(user_id: current_user.id)
	end

	def post_comment_params
		params.require(:post_comment).permit(:comment, :community_post_id, :user_id).merge(user_id: current_user.id)
	end
end
