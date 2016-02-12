function R = dcm( yaw, pitch, roll)

angles = [yaw(:) pitch(:) roll(:)];

R = zeros(3,3,size(angles,1));
cang = cosd( angles );
sang = sind( angles );

R(1,1,:) = cang(:,2).*cang(:,1);
R(1,2,:) = cang(:,2).*sang(:,1);
R(1,3,:) = -sang(:,2);
R(2,1,:) = sang(:,3).*sang(:,2).*cang(:,1) - cang(:,3).*sang(:,1);
R(2,2,:) = sang(:,3).*sang(:,2).*sang(:,1) + cang(:,3).*cang(:,1);
R(2,3,:) = sang(:,3).*cang(:,2);
R(3,1,:) = cang(:,3).*sang(:,2).*cang(:,1) + sang(:,3).*sang(:,1);
R(3,2,:) = cang(:,3).*sang(:,2).*sang(:,1) - sang(:,3).*cang(:,1);
R(3,3,:) = cang(:,3).*cang(:,2);

end

